const MODULE_STATUS = { draft: 'Rascunho', published: 'Publicado', archived: 'Arquivado' };
const LESSON_TYPE = { video: 'Videoaula', text: 'Texto', download: 'Download', live: 'Ao vivo' };

function slugify(value = '') {
  return String(value).normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase().trim().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '').slice(0, 120);
}

function youtubeId(value = '') {
  const text = String(value).trim();
  if (!text) return null;
  const patterns = [/youtu\.be\/([A-Za-z0-9_-]{6,})/, /[?&]v=([A-Za-z0-9_-]{6,})/, /embed\/([A-Za-z0-9_-]{6,})/, /shorts\/([A-Za-z0-9_-]{6,})/];
  for (const pattern of patterns) {
    const match = text.match(pattern);
    if (match) return match[1];
  }
  return text.replace(/[^A-Za-z0-9_-]/g, '').slice(0, 32) || null;
}

export function createCurriculumAdmin({ supabase, canEdit, escapeHtml }) {
  const state = { root: null, course: null, modules: [], lessons: [], bound: false };

  function feedback(selector, message, type = 'error') {
    const element = state.root.querySelector(selector);
    element.textContent = message;
    element.className = `course-feedback is-visible is-${type}`;
  }

  function shell() {
    return `<section class="curriculum-section">
      <div class="curriculum-header"><div><h2>Conteúdo programático</h2><p>Organize os módulos e as aulas na sequência da formação.</p></div>${canEdit() ? '<button class="button button-small" type="button" data-module-new>Adicionar módulo</button>' : ''}</div>
      <div class="module-list" data-module-list><div class="module-empty">Carregando conteúdo…</div></div>

      <dialog class="curriculum-dialog" data-module-dialog>
        <form method="dialog" data-module-form>
          <div class="dialog-header"><div><h2 data-module-dialog-title>Novo módulo</h2><p>Defina o tema e quando ele será liberado.</p></div><button class="dialog-close" type="button" data-close-dialog aria-label="Fechar">×</button></div>
          <div class="dialog-body"><input type="hidden" name="id"><div class="dialog-grid">
            <div class="field is-full"><label for="module-title">Título</label><input id="module-title" name="title" type="text" minlength="3" maxlength="180" required></div>
            <div class="field is-full"><label for="module-description">Descrição</label><textarea id="module-description" name="description" maxlength="1200"></textarea></div>
            <div class="field"><label for="module-release">Liberação</label><select id="module-release" name="release_type"><option value="immediate">Imediata</option><option value="days_after_enrollment">Dias após matrícula</option><option value="fixed_date">Data específica</option></select></div>
            <div class="field"><label for="module-status">Situação</label><select id="module-status" name="status"><option value="draft">Rascunho</option><option value="published">Publicado</option></select></div>
            <div class="field" data-release-days hidden><label for="module-days">Quantidade de dias</label><input id="module-days" name="release_after_days" type="number" min="0" step="1" value="0"></div>
            <div class="field" data-release-date hidden><label for="module-date">Data de liberação</label><input id="module-date" name="release_at" type="datetime-local"></div>
          </div><p class="course-feedback" data-module-feedback></p><div class="dialog-actions"><button class="button" type="submit" data-module-save>Salvar módulo</button><button class="button button-secondary" type="button" data-close-dialog>Cancelar</button></div></div>
        </form>
      </dialog>

      <dialog class="curriculum-dialog" data-lesson-dialog>
        <form method="dialog" data-lesson-form>
          <div class="dialog-header"><div><h2 data-lesson-dialog-title>Nova aula</h2><p>Cadastre o formato e o conteúdo da aula.</p></div><button class="dialog-close" type="button" data-close-dialog aria-label="Fechar">×</button></div>
          <div class="dialog-body"><input type="hidden" name="id"><input type="hidden" name="course_module_id"><div class="dialog-grid">
            <div class="field is-full"><label for="lesson-title">Título</label><input id="lesson-title" name="title" type="text" minlength="3" maxlength="180" required></div>
            <div class="field is-full"><label for="lesson-slug">Endereço amigável</label><input id="lesson-slug" name="slug" type="text" maxlength="120" required></div>
            <div class="field"><label for="lesson-type">Formato</label><select id="lesson-type" name="lesson_type">${Object.entries(LESSON_TYPE).map(([value,label]) => `<option value="${value}">${label}</option>`).join('')}</select></div>
            <div class="field"><label for="lesson-status">Situação</label><select id="lesson-status" name="status"><option value="draft">Rascunho</option><option value="published">Publicado</option></select></div>
            <div class="field"><label for="lesson-duration">Duração em minutos</label><input id="lesson-duration" name="duration_minutes" type="number" min="0" step="1"></div>
            <label class="checkbox-field"><input name="is_preview" type="checkbox"><span>Liberar prévia pública</span></label>
            <div class="field is-full" data-youtube-field><label for="lesson-video">Vídeo do YouTube</label><input id="lesson-video" name="youtube_video_id" type="text" placeholder="Link ou ID do vídeo"></div>
            <div class="field is-full"><label for="lesson-description">Resumo</label><textarea id="lesson-description" name="description" maxlength="1200"></textarea></div>
            <div class="field is-full"><label for="lesson-content">Conteúdo em texto</label><textarea id="lesson-content" name="content_html" maxlength="20000"></textarea></div>
          </div><p class="course-feedback" data-lesson-feedback></p><div class="dialog-actions"><button class="button" type="submit" data-lesson-save>Salvar aula</button><button class="button button-secondary" type="button" data-close-dialog>Cancelar</button></div></div>
        </form>
      </dialog>
    </section>`;
  }

  async function load() {
    const { data: modules, error: moduleError } = await supabase.from('course_modules').select('id,course_id,title,description,position,release_type,release_after_days,release_at,status,updated_at').eq('course_id', state.course.id).neq('status', 'archived').order('position');
    if (moduleError) throw moduleError;
    state.modules = modules || [];
    if (!state.modules.length) { state.lessons = []; return; }
    const { data: lessons, error: lessonError } = await supabase.from('lessons').select('id,course_module_id,title,slug,description,content_html,lesson_type,video_provider,youtube_video_id,duration_seconds,position,is_preview,status,published_at,updated_at').in('course_module_id', state.modules.map((item) => item.id)).neq('status', 'archived').order('position');
    if (lessonError) throw lessonError;
    state.lessons = lessons || [];
  }

  function releaseLabel(module) {
    if (module.release_type === 'days_after_enrollment') return `${module.release_after_days || 0} dia(s) após a matrícula`;
    if (module.release_type === 'fixed_date') return module.release_at ? `Liberação em ${new Date(module.release_at).toLocaleString('pt-BR')}` : 'Data não definida';
    return 'Liberação imediata';
  }

  function render() {
    const list = state.root.querySelector('[data-module-list]');
    if (!state.modules.length) {
      list.innerHTML = `<div class="module-empty">Nenhum módulo cadastrado.${canEdit() ? ' Clique em “Adicionar módulo” para começar.' : ''}</div>`;
      return;
    }
    list.innerHTML = state.modules.map((module) => {
      const lessons = state.lessons.filter((lesson) => lesson.course_module_id === module.id);
      return `<article class="module-card"><div class="module-card-header"><div class="module-title-line"><div><h3>${module.position}. ${escapeHtml(module.title)}</h3><p>${escapeHtml(module.description || releaseLabel(module))}</p></div><span class="course-status${module.status === 'published' ? ' is-published' : ''}">${MODULE_STATUS[module.status]}</span></div>${canEdit() ? `<div class="module-actions"><button class="compact-button" type="button" data-module-edit="${module.id}">Editar</button><button class="compact-button" type="button" data-lesson-new="${module.id}">Adicionar aula</button><button class="compact-button is-danger" type="button" data-module-archive="${module.id}">Arquivar</button></div>` : ''}</div><div class="lesson-list">${lessons.length ? lessons.map((lesson) => `<div class="lesson-row"><div class="lesson-row-main"><span class="lesson-number">${lesson.position}</span><div class="lesson-copy"><strong>${escapeHtml(lesson.title)}</strong><span>${LESSON_TYPE[lesson.lesson_type]} · ${MODULE_STATUS[lesson.status]}${lesson.is_preview ? ' · Prévia' : ''}</span></div></div>${canEdit() ? `<div class="lesson-actions"><button class="compact-button" type="button" data-lesson-edit="${lesson.id}">Editar</button><button class="compact-button is-danger" type="button" data-lesson-archive="${lesson.id}">Arquivar</button></div>` : ''}</div>`).join('') : '<div class="module-empty">Nenhuma aula cadastrada.</div>'}</div></article>`;
    }).join('');
    list.querySelectorAll('[data-module-edit]').forEach((button) => button.addEventListener('click', () => openModule(button.dataset.moduleEdit)));
    list.querySelectorAll('[data-lesson-new]').forEach((button) => button.addEventListener('click', () => openLesson(button.dataset.lessonNew)));
    list.querySelectorAll('[data-lesson-edit]').forEach((button) => button.addEventListener('click', () => openLesson(null, button.dataset.lessonEdit)));
    list.querySelectorAll('[data-module-archive]').forEach((button) => button.addEventListener('click', () => archiveModule(button.dataset.moduleArchive)));
    list.querySelectorAll('[data-lesson-archive]').forEach((button) => button.addEventListener('click', () => archiveLesson(button.dataset.lessonArchive)));
  }

  function syncReleaseFields() {
    const form = state.root.querySelector('[data-module-form]');
    state.root.querySelector('[data-release-days]').hidden = form.elements.release_type.value !== 'days_after_enrollment';
    state.root.querySelector('[data-release-date]').hidden = form.elements.release_type.value !== 'fixed_date';
  }

  function syncLessonFields() {
    const form = state.root.querySelector('[data-lesson-form]');
    state.root.querySelector('[data-youtube-field]').hidden = form.elements.lesson_type.value !== 'video';
  }

  function openModule(id = null) {
    const form = state.root.querySelector('[data-module-form]');
    const item = id ? state.modules.find((module) => module.id === id) : null;
    form.reset();
    form.elements.id.value = item?.id || '';
    form.elements.title.value = item?.title || '';
    form.elements.description.value = item?.description || '';
    form.elements.release_type.value = item?.release_type || 'immediate';
    form.elements.release_after_days.value = item?.release_after_days ?? 0;
    form.elements.release_at.value = item?.release_at ? new Date(item.release_at).toISOString().slice(0,16) : '';
    form.elements.status.value = item?.status || 'draft';
    state.root.querySelector('[data-module-dialog-title]').textContent = item ? 'Editar módulo' : 'Novo módulo';
    state.root.querySelector('[data-module-feedback]').className = 'course-feedback';
    syncReleaseFields();
    state.root.querySelector('[data-module-dialog]').showModal();
    form.elements.title.focus();
  }

  async function saveModule(event) {
    event.preventDefault();
    const form = event.currentTarget;
    const data = new FormData(form);
    const id = String(data.get('id') || '');
    const title = String(data.get('title') || '').trim();
    if (title.length < 3) { feedback('[data-module-feedback]', 'Informe um título com pelo menos 3 caracteres.'); return; }
    const type = String(data.get('release_type') || 'immediate');
    const payload = { title, description: String(data.get('description') || '').trim() || null, release_type: type, release_after_days: type === 'days_after_enrollment' ? Math.max(0, Number(data.get('release_after_days') || 0)) : null, release_at: type === 'fixed_date' && data.get('release_at') ? new Date(String(data.get('release_at'))).toISOString() : null, status: String(data.get('status') || 'draft') };
    const button = form.querySelector('[data-module-save]');
    button.disabled = true; button.textContent = 'Salvando…';
    try {
      const response = id ? await supabase.from('course_modules').update(payload).eq('id', id) : await supabase.from('course_modules').insert({ ...payload, course_id: state.course.id, position: Math.max(0, ...state.modules.map((module) => module.position)) + 1 });
      if (response.error) throw response.error;
      state.root.querySelector('[data-module-dialog]').close();
      await load(); render();
    } catch (error) { console.error(error); feedback('[data-module-feedback]', 'Não foi possível salvar o módulo.'); }
    finally { button.disabled = false; button.textContent = 'Salvar módulo'; }
  }

  function openLesson(moduleId = null, lessonId = null) {
    const form = state.root.querySelector('[data-lesson-form]');
    const item = lessonId ? state.lessons.find((lesson) => lesson.id === lessonId) : null;
    form.reset();
    form.elements.id.value = item?.id || '';
    form.elements.course_module_id.value = item?.course_module_id || moduleId || '';
    form.elements.title.value = item?.title || '';
    form.elements.slug.value = item?.slug || '';
    form.elements.description.value = item?.description || '';
    form.elements.content_html.value = item?.content_html || '';
    form.elements.lesson_type.value = item?.lesson_type || 'video';
    form.elements.status.value = item?.status || 'draft';
    form.elements.duration_minutes.value = item?.duration_seconds ? Math.ceil(item.duration_seconds / 60) : '';
    form.elements.youtube_video_id.value = item?.youtube_video_id || '';
    form.elements.is_preview.checked = Boolean(item?.is_preview);
    form.elements.slug.dataset.touched = item ? 'true' : '';
    state.root.querySelector('[data-lesson-dialog-title]').textContent = item ? 'Editar aula' : 'Nova aula';
    state.root.querySelector('[data-lesson-feedback]').className = 'course-feedback';
    syncLessonFields();
    state.root.querySelector('[data-lesson-dialog]').showModal();
    form.elements.title.focus();
  }

  async function saveLesson(event) {
    event.preventDefault();
    const form = event.currentTarget;
    const data = new FormData(form);
    const id = String(data.get('id') || '');
    const moduleId = String(data.get('course_module_id') || '');
    const title = String(data.get('title') || '').trim();
    const slug = slugify(data.get('slug') || title);
    const type = String(data.get('lesson_type') || 'video');
    const video = type === 'video' ? youtubeId(data.get('youtube_video_id')) : null;
    if (title.length < 3 || !slug) { feedback('[data-lesson-feedback]', 'Informe um título e um endereço válidos.'); return; }
    if (type === 'video' && !video) { feedback('[data-lesson-feedback]', 'Informe o link ou ID do vídeo.'); return; }
    const status = String(data.get('status') || 'draft');
    const existing = state.lessons.find((lesson) => lesson.id === id);
    const payload = { title, slug, description: String(data.get('description') || '').trim() || null, content_html: String(data.get('content_html') || '').trim() || null, lesson_type: type, video_provider: type === 'video' ? 'youtube' : 'none', youtube_video_id: video, duration_seconds: Math.max(0, Number(data.get('duration_minutes') || 0)) * 60 || null, is_preview: data.get('is_preview') === 'on', status, published_at: status === 'published' ? (existing?.published_at || new Date().toISOString()) : null };
    const button = form.querySelector('[data-lesson-save]');
    button.disabled = true; button.textContent = 'Salvando…';
    try {
      const response = id ? await supabase.from('lessons').update(payload).eq('id', id) : await supabase.from('lessons').insert({ ...payload, course_module_id: moduleId, position: Math.max(0, ...state.lessons.filter((lesson) => lesson.course_module_id === moduleId).map((lesson) => lesson.position)) + 1 });
      if (response.error) throw response.error;
      state.root.querySelector('[data-lesson-dialog]').close();
      await load(); render();
    } catch (error) { console.error(error); feedback('[data-lesson-feedback]', error.code === '23505' ? 'Já existe uma aula com este endereço.' : 'Não foi possível salvar a aula.'); }
    finally { button.disabled = false; button.textContent = 'Salvar aula'; }
  }

  async function archiveModule(id) {
    const item = state.modules.find((module) => module.id === id);
    if (!item || !window.confirm(`Arquivar o módulo “${item.title}”?`)) return;
    const { error } = await supabase.from('course_modules').update({ status: 'archived' }).eq('id', id);
    if (error) return window.alert('Não foi possível arquivar o módulo.');
    await load(); render();
  }

  async function archiveLesson(id) {
    const item = state.lessons.find((lesson) => lesson.id === id);
    if (!item || !window.confirm(`Arquivar a aula “${item.title}”?`)) return;
    const { error } = await supabase.from('lessons').update({ status: 'archived' }).eq('id', id);
    if (error) return window.alert('Não foi possível arquivar a aula.');
    await load(); render();
  }

  function bind() {
    state.root.querySelector('[data-module-new]')?.addEventListener('click', () => openModule());
    state.root.querySelector('[data-module-form]').addEventListener('submit', saveModule);
    state.root.querySelector('[data-lesson-form]').addEventListener('submit', saveLesson);
    state.root.querySelector('[data-module-form]').elements.release_type.addEventListener('change', syncReleaseFields);
    state.root.querySelector('[data-lesson-form]').elements.lesson_type.addEventListener('change', syncLessonFields);
    state.root.querySelectorAll('[data-close-dialog]').forEach((button) => button.addEventListener('click', () => button.closest('dialog')?.close()));
    const lessonForm = state.root.querySelector('[data-lesson-form]');
    lessonForm.elements.title.addEventListener('input', () => { if (!lessonForm.elements.slug.dataset.touched) lessonForm.elements.slug.value = slugify(lessonForm.elements.title.value); });
    lessonForm.elements.slug.addEventListener('input', () => { lessonForm.elements.slug.dataset.touched = 'true'; lessonForm.elements.slug.value = slugify(lessonForm.elements.slug.value); });
  }

  async function mount(root, course) {
    if (!root || !course?.id) return;
    state.root = root;
    state.course = course;
    state.root.innerHTML = shell();
    bind();
    try { await load(); render(); }
    catch (error) { console.error(error); state.root.querySelector('[data-module-list]').innerHTML = '<div class="module-empty">Não foi possível carregar o conteúdo programático.</div>'; }
  }

  return { mount };
}
