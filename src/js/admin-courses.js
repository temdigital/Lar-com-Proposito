const STATUS_LABELS = { draft: 'Rascunho', review: 'Em revisão', published: 'Publicado', archived: 'Arquivado' };
const ACCESS_LABELS = { free: 'Gratuito', paid: 'Compra avulsa', subscription: 'Assinatura', invite: 'Convite' };

function slugify(value = '') {
  return String(value).normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase().trim().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '').slice(0, 120);
}

function money(value) {
  return Number(value || 0).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' });
}

export function createCoursesAdmin({ supabase, context, session, canAny, escapeHtml, onChanged }) {
  const state = { container: null, courses: [], selected: null, slugTouched: false, mounted: false };
  const organizationId = context.organization?.id;
  const canManage = () => canAny(['courses.manage']);
  const canEdit = () => canManage() || canAny(['courses.edit_assigned']);

  function feedback(message, type = 'success') {
    const element = state.container?.querySelector('[data-course-feedback]');
    if (!element) return;
    element.textContent = message;
    element.className = `course-feedback is-visible is-${type}`;
  }

  function statusClass(status) {
    return status === 'published' ? ' is-published' : status === 'review' ? ' is-review' : status === 'archived' ? ' is-archived' : '';
  }

  function shell() {
    return `<div class="course-admin">
      <header class="course-admin-header">
        <div><p class="admin-eyebrow">Formação</p><h1>Cursos</h1><p>Cadastre formações, defina o acesso e prepare a estrutura para módulos e aulas.</p></div>
        ${canManage() ? '<button class="button" type="button" data-course-new>Novo curso</button>' : ''}
      </header>
      <section class="course-toolbar">
        <div class="field"><label for="course-search">Pesquisar</label><input id="course-search" type="search" placeholder="Título, subtítulo ou endereço" data-course-search></div>
        <div class="field"><label for="course-status-filter">Situação</label><select id="course-status-filter" data-course-filter><option value="all">Todas</option>${Object.entries(STATUS_LABELS).map(([value,label]) => `<option value="${value}">${label}</option>`).join('')}</select></div>
      </section>
      <div class="course-admin-layout">
        <section class="course-list-panel"><div class="course-panel-title"><div><h2>Formações</h2><p><span data-course-total>0</span> curso(s)</p></div></div><div class="course-list" data-course-list></div></section>
        <section class="course-editor-panel" data-course-editor></section>
      </div>
    </div>`;
  }

  function emptyEditor() {
    return `<div class="course-editor-empty"><div><strong>Selecione uma formação</strong><p>Escolha um curso para editar seus dados.${canManage() ? ' Você também pode iniciar uma nova formação.' : ''}</p>${canManage() ? '<button class="button" type="button" data-course-new>Começar novo curso</button>' : ''}</div></div>`;
  }

  function formTemplate(course = null) {
    const isNew = !course?.id;
    const editable = canEdit();
    const manager = canManage();
    return `<div class="course-editor-header">
      <div><p class="admin-eyebrow">${isNew ? 'Nova formação' : 'Editar formação'}</p><h2>${escapeHtml(course?.title || 'Criar curso')}</h2><p>${isNew ? 'Preencha os dados básicos e salve o curso.' : `Atualizado em ${new Date(course.updated_at).toLocaleString('pt-BR')}.`}</p></div>
      ${!isNew && manager ? '<button class="compact-button is-danger" type="button" data-course-archive>Arquivar</button>' : ''}
    </div>
    <form class="course-form" data-course-form novalidate>
      <input type="hidden" name="id" value="${escapeHtml(course?.id || '')}">
      <div class="course-form-grid">
        <div class="field is-full"><label for="course-title">Título</label><input id="course-title" name="title" type="text" minlength="3" maxlength="180" value="${escapeHtml(course?.title || '')}" ${editable ? '' : 'disabled'} required></div>
        <div class="field is-full"><label for="course-slug">Endereço amigável</label><input id="course-slug" name="slug" type="text" maxlength="120" value="${escapeHtml(course?.slug || '')}" ${editable ? '' : 'disabled'} required><p class="field-hint">Exemplo: mesa-posta-com-proposito</p></div>
        <div class="field is-full"><label for="course-subtitle">Subtítulo</label><input id="course-subtitle" name="subtitle" type="text" maxlength="220" value="${escapeHtml(course?.subtitle || '')}" ${editable ? '' : 'disabled'}></div>
        <div class="field is-full"><label for="course-description">Descrição</label><textarea id="course-description" name="description" maxlength="3000" ${editable ? '' : 'disabled'}>${escapeHtml(course?.description || '')}</textarea></div>
        <div class="field"><label for="course-status">Situação</label><select id="course-status" name="status" ${manager ? '' : 'disabled'}>${Object.entries(STATUS_LABELS).map(([value,label]) => `<option value="${value}"${(course?.status || 'draft') === value ? ' selected' : ''}>${label}</option>`).join('')}</select></div>
        <div class="field"><label for="course-access">Forma de acesso</label><select id="course-access" name="access_type" ${editable ? '' : 'disabled'}>${Object.entries(ACCESS_LABELS).map(([value,label]) => `<option value="${value}"${(course?.access_type || 'paid') === value ? ' selected' : ''}>${label}</option>`).join('')}</select></div>
        <div class="field"><label for="course-price">Preço</label><input id="course-price" name="price" type="number" min="0" step="0.01" value="${Number(course?.price || 0).toFixed(2)}" ${editable ? '' : 'disabled'}></div>
        <label class="checkbox-field"><input name="certificate_enabled" type="checkbox"${course?.certificate_enabled ? ' checked' : ''} ${editable ? '' : 'disabled'}><span>Emitir certificado após conclusão</span></label>
      </div>
      ${course?.id ? `<div class="course-summary-grid"><article><strong data-course-module-count>—</strong><span>Módulos</span></article><article><strong data-course-lesson-count>—</strong><span>Aulas</span></article><article><strong data-course-enrollment-count>—</strong><span>Matrículas</span></article></div>` : ''}
      <p class="course-feedback" data-course-feedback role="status" aria-live="polite"></p>
      ${editable ? `<div class="course-form-actions"><button class="button" type="submit" data-course-save>${isNew ? 'Criar curso' : 'Salvar alterações'}</button>${isNew ? '<button class="button button-secondary" type="button" data-course-cancel>Cancelar</button>' : ''}</div>` : ''}
    </form>`;
  }

  function filteredCourses() {
    const search = state.container.querySelector('[data-course-search]')?.value.trim().toLowerCase() || '';
    const filter = state.container.querySelector('[data-course-filter]')?.value || 'all';
    return state.courses.filter((course) => {
      const text = [course.title, course.subtitle, course.slug].filter(Boolean).join(' ').toLowerCase();
      return (filter === 'all' || course.status === filter) && (!search || text.includes(search));
    });
  }

  function renderList() {
    const list = state.container.querySelector('[data-course-list]');
    const courses = filteredCourses();
    state.container.querySelector('[data-course-total]').textContent = String(courses.length);
    if (!courses.length) {
      list.innerHTML = '<div class="course-list-empty"><strong>Nenhum curso encontrado</strong><p>Altere os filtros ou crie uma formação.</p></div>';
      return;
    }
    list.innerHTML = courses.map((course) => `<button class="course-list-item${state.selected?.id === course.id ? ' is-active' : ''}" type="button" data-course-id="${course.id}"><div class="course-item-meta"><span class="course-status${statusClass(course.status)}">${STATUS_LABELS[course.status]}</span><span class="course-access">${ACCESS_LABELS[course.access_type]}</span></div><div><h3>${escapeHtml(course.title)}</h3><p>${escapeHtml(course.subtitle || course.description || 'Sem descrição cadastrada.')}</p></div><div class="course-item-footer"><span>${money(course.price)}</span><span>${new Date(course.updated_at).toLocaleDateString('pt-BR')}</span></div></button>`).join('');
    list.querySelectorAll('[data-course-id]').forEach((button) => button.addEventListener('click', () => selectCourse(button.dataset.courseId)));
  }

  async function loadCourses() {
    let query = supabase.from('courses').select('id,organization_id,title,slug,subtitle,description,status,access_type,price,certificate_enabled,published_at,created_at,updated_at').is('deleted_at', null).order('updated_at', { ascending: false });
    if (organizationId) query = query.eq('organization_id', organizationId);
    const { data, error } = await query;
    if (error) throw error;
    state.courses = data || [];
    if (state.selected) state.selected = state.courses.find((course) => course.id === state.selected.id) || null;
    renderList();
  }

  async function loadSummary(courseId) {
    const [modules, lessons, enrollments] = await Promise.all([
      supabase.from('course_modules').select('*', { count: 'exact', head: true }).eq('course_id', courseId).neq('status', 'archived'),
      supabase.from('course_modules').select('id').eq('course_id', courseId).neq('status', 'archived'),
      supabase.from('enrollments').select('*', { count: 'exact', head: true }).eq('course_id', courseId)
    ]);
    const moduleIds = (lessons.data || []).map((item) => item.id);
    let lessonCount = 0;
    if (moduleIds.length) {
      const response = await supabase.from('lessons').select('*', { count: 'exact', head: true }).in('course_module_id', moduleIds).neq('status', 'archived');
      lessonCount = response.count || 0;
    }
    state.container.querySelector('[data-course-module-count]').textContent = String(modules.count || 0);
    state.container.querySelector('[data-course-lesson-count]').textContent = String(lessonCount);
    state.container.querySelector('[data-course-enrollment-count]').textContent = enrollments.error ? '—' : String(enrollments.count || 0);
  }

  function bindForm(course) {
    const editor = state.container.querySelector('[data-course-editor]');
    const form = editor.querySelector('[data-course-form]');
    const title = form?.elements.title;
    const slug = form?.elements.slug;
    const access = form?.elements.access_type;
    const price = form?.elements.price;
    state.slugTouched = Boolean(course?.slug);
    title?.addEventListener('input', () => { if (!state.slugTouched) slug.value = slugify(title.value); });
    slug?.addEventListener('input', () => { state.slugTouched = true; slug.value = slugify(slug.value); });
    access?.addEventListener('change', () => { const zero = ['free','invite'].includes(access.value); if (zero) price.value = '0.00'; price.disabled = zero || !canEdit(); });
    access?.dispatchEvent(new Event('change'));
    form?.addEventListener('submit', saveCourse);
    editor.querySelector('[data-course-cancel]')?.addEventListener('click', () => { state.selected = null; renderList(); renderEditor(); });
    editor.querySelector('[data-course-archive]')?.addEventListener('click', archiveCourse);
    if (course?.id) loadSummary(course.id).catch(console.warn);
  }

  function renderEditor(course = null) {
    const editor = state.container.querySelector('[data-course-editor]');
    editor.innerHTML = course ? formTemplate(course) : emptyEditor();
    editor.querySelector('[data-course-new]')?.addEventListener('click', newCourse);
    if (course) bindForm(course);
  }

  function newCourse() {
    if (!canManage()) return;
    state.selected = null;
    renderList();
    const editor = state.container.querySelector('[data-course-editor]');
    editor.innerHTML = formTemplate(null);
    bindForm(null);
    editor.querySelector('[name="title"]')?.focus();
  }

  async function selectCourse(id) {
    state.selected = state.courses.find((course) => course.id === id) || null;
    renderList();
    renderEditor(state.selected);
  }

  async function saveCourse(event) {
    event.preventDefault();
    if (!canEdit()) return;
    const form = event.currentTarget;
    const data = new FormData(form);
    const id = String(data.get('id') || '');
    const existing = state.courses.find((course) => course.id === id);
    const title = String(data.get('title') || '').trim();
    const slug = slugify(data.get('slug') || title);
    const accessType = String(data.get('access_type') || existing?.access_type || 'paid');
    const status = canManage() ? String(data.get('status') || existing?.status || 'draft') : existing?.status || 'draft';
    if (title.length < 3 || !slug) { feedback('Informe um título e um endereço amigável válidos.', 'error'); return; }
    const button = form.querySelector('[data-course-save]');
    button.disabled = true;
    button.textContent = 'Salvando…';
    const payload = {
      title,
      slug,
      subtitle: String(data.get('subtitle') || '').trim() || null,
      description: String(data.get('description') || '').trim() || null,
      access_type: accessType,
      price: ['free','invite'].includes(accessType) ? 0 : Math.max(0, Number(data.get('price') || 0)),
      certificate_enabled: data.get('certificate_enabled') === 'on',
      updated_by: session.user.id
    };
    if (canManage()) {
      payload.status = status;
      payload.published_at = status === 'published' ? (existing?.published_at || new Date().toISOString()) : existing?.published_at || null;
    }
    try {
      const response = id
        ? await supabase.from('courses').update(payload).eq('id', id).select().single()
        : await supabase.from('courses').insert({ ...payload, organization_id: organizationId, created_by: session.user.id, status }).select().single();
      if (response.error) throw response.error;
      state.selected = response.data;
      await loadCourses();
      renderEditor(state.selected);
      feedback(id ? 'Curso atualizado com sucesso.' : 'Curso criado. A estrutura de módulos e aulas será liberada na próxima etapa.', 'success');
      await onChanged?.();
    } catch (error) {
      console.error(error);
      feedback(error.code === '23505' ? 'Já existe um curso com este endereço amigável.' : 'Não foi possível salvar o curso.', 'error');
    } finally {
      button.disabled = false;
      button.textContent = id ? 'Salvar alterações' : 'Criar curso';
    }
  }

  async function archiveCourse() {
    if (!canManage() || !state.selected?.id) return;
    if (!window.confirm(`Arquivar o curso “${state.selected.title}”? O histórico será preservado.`)) return;
    const { error } = await supabase.from('courses').update({ status: 'archived', deleted_at: new Date().toISOString(), updated_by: session.user.id }).eq('id', state.selected.id);
    if (error) { feedback('Não foi possível arquivar o curso.', 'error'); return; }
    state.selected = null;
    await loadCourses();
    renderEditor();
    await onChanged?.();
  }

  async function mount(container) {
    state.container = container;
    if (!state.mounted) {
      container.innerHTML = shell();
      container.querySelectorAll('[data-course-new]').forEach((button) => button.addEventListener('click', newCourse));
      container.querySelector('[data-course-search]').addEventListener('input', renderList);
      container.querySelector('[data-course-filter]').addEventListener('change', renderList);
      state.mounted = true;
    }
    try {
      await loadCourses();
      renderEditor(state.selected);
    } catch (error) {
      console.error(error);
      container.querySelector('[data-course-list]').innerHTML = '<div class="course-list-empty"><strong>Não foi possível carregar os cursos</strong><p>Verifique sua conexão e suas permissões.</p></div>';
    }
  }

  return { mount, reload: () => mount(state.container) };
}
