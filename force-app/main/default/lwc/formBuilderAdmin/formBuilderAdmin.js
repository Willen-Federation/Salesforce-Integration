import { LightningElement, track } from 'lwc';
import getAllTemplates  from '@salesforce/apex/FormBuilderController.getAllTemplates';
import getTemplate     from '@salesforce/apex/FormBuilderController.getTemplate';
import getFields       from '@salesforce/apex/FormBuilderController.getFields';
import createTemplate  from '@salesforce/apex/FormBuilderController.createTemplate';
import saveFields      from '@salesforce/apex/FormBuilderController.saveFields';
import toggleActive    from '@salesforce/apex/FormBuilderController.toggleActive';
import duplicateTemplate from '@salesforce/apex/FormBuilderController.duplicateTemplate';

export default class FormBuilderAdmin extends LightningElement {
    @track templates = [];
    @track fields = [];
    @track isLoading = false;
    @track isSaving = false;
    @track errorMessage = '';
    @track selectedTemplateId = null;

    form = {
        name: '', formType: 'カスタム', description: '',
        responseDeadline: '', requiresAuth: true, saveToRecord: true,
        sendConfirmation: true, confirmationTemplate: ''
    };

    isNewTemplate = false;

    formTypeOptions = [
        { label: '出欠確認', value: '出欠確認' },
        { label: '委任状', value: '委任状' },
        { label: '議決権行使', value: '議決権行使' },
        { label: 'アンケート', value: 'アンケート' },
        { label: '参加申込', value: '参加申込' },
        { label: 'カスタム', value: 'カスタム' }
    ];

    fieldTypeOptions = [
        { label: 'テキスト', value: 'テキスト' },
        { label: 'テキストエリア', value: 'テキストエリア' },
        { label: '選択（単一）', value: '選択（単一）' },
        { label: '選択（複数）', value: '選択（複数）' },
        { label: 'チェックボックス', value: 'チェックボックス' },
        { label: '日付', value: '日付' },
        { label: '数値', value: '数値' },
        { label: 'メールアドレス', value: 'メールアドレス' },
        { label: '署名', value: '署名' },
        { label: 'セクション区切り', value: 'セクション区切り' }
    ];

    connectedCallback() {
        this.loadTemplates();
    }

    loadTemplates() {
        this.isLoading = true;
        getAllTemplates()
            .then(data => {
                this.templates = data.map(t => ({
                    ...t,
                    toggleLabel: t.IsActive__c ? '受付終了' : '受付開始'
                }));
                this.isLoading = false;
            })
            .catch(err => { this.errorMessage = err.body?.message; this.isLoading = false; });
    }

    handleNewTemplate() {
        this.selectedTemplateId = 'new';
        this.isNewTemplate = true;
        this.form = { name: '', formType: 'カスタム', description: '', responseDeadline: '', requiresAuth: true, saveToRecord: true, sendConfirmation: true, confirmationTemplate: '' };
        this.fields = [];
    }

    handleSelectTemplate(event) {
        const id = event.currentTarget.dataset.id;
        this.selectedTemplateId = id;
        this.isNewTemplate = false;
        this.isLoading = true;
        Promise.all([getTemplate({ templateId: id }), getFields({ templateId: id })])
            .then(([tmpl, flds]) => {
                this.form = {
                    name:                tmpl.Name,
                    formType:            tmpl.FormType__c,
                    description:         tmpl.Description__c || '',
                    responseDeadline:    tmpl.ResponseDeadline__c ? tmpl.ResponseDeadline__c.replace('Z', '') : '',
                    requiresAuth:        tmpl.RequiresAuth__c,
                    saveToRecord:        tmpl.SaveToRecord__c,
                    sendConfirmation:    tmpl.SendConfirmationEmail__c,
                    confirmationTemplate: tmpl.ConfirmationEmailTemplate__c || ''
                };
                this.fields = flds.map((f, i) => this.toEditorField(f, i));
                this.isLoading = false;
            })
            .catch(() => { this.isLoading = false; });
    }

    handleBack() {
        this.selectedTemplateId = null;
        this.isNewTemplate = false;
        this.loadTemplates();
    }

    handleFormChange(event) {
        const field = event.target.dataset.field;
        this.form = { ...this.form, [field]: event.target.value };
    }

    handleCheckChange(event) {
        const field = event.target.dataset.field;
        this.form = { ...this.form, [field]: event.target.checked };
    }

    handleAddField() {
        this.fields = [...this.fields, this.toEditorField({}, this.fields.length)];
    }

    handleRemoveField(event) {
        const idx = parseInt(event.currentTarget.dataset.idx, 10);
        this.fields = this.fields.filter((_, i) => i !== idx);
    }

    handleFieldChange(event) {
        const idx  = parseInt(event.currentTarget.dataset.idx, 10);
        const prop = event.currentTarget.dataset.prop;
        const val  = event.target.value;
        this.fields = this.fields.map((f, i) => {
            if (i !== idx) return f;
            const updated = { ...f, [prop]: val };
            if (prop === 'fieldType') updated.showOptions = ['選択（単一）','選択（複数）'].includes(val);
            return updated;
        });
    }

    handleFieldCheckChange(event) {
        const idx  = parseInt(event.currentTarget.dataset.idx, 10);
        const prop = event.currentTarget.dataset.prop;
        this.fields = this.fields.map((f, i) => i === idx ? { ...f, [prop]: event.target.checked } : f);
    }

    handleSave() {
        if (!this.form.name) { this.errorMessage = 'フォーム名を入力してください。'; return; }
        this.isSaving = true;
        this.errorMessage = '';

        const templatePromise = this.isNewTemplate
            ? createTemplate({ templateData: this.form })
            : Promise.resolve(this.selectedTemplateId);

        templatePromise
            .then(id => {
                this.selectedTemplateId = id;
                this.isNewTemplate = false;
                return saveFields({ templateId: id, fields: this.fields.map(f => ({
                    label: f.label, fieldType: f.fieldType, isRequired: f.isRequired,
                    picklistOptions: f.picklistOptions, placeholder: f.placeholder,
                    helpText: f.helpText, apiKey: f.apiKey
                }))});
            })
            .then(() => { this.isSaving = false; this.loadTemplates(); })
            .catch(err => { this.errorMessage = err.body?.message || '保存に失敗しました。'; this.isSaving = false; });
    }

    handleToggleActive(event) {
        const id     = event.currentTarget.dataset.id;
        const active = event.currentTarget.dataset.active === 'true';
        toggleActive({ templateId: id, isActive: !active }).then(() => this.loadTemplates());
    }

    handleDuplicate(event) {
        const id = event.currentTarget.dataset.id;
        duplicateTemplate({ templateId: id }).then(() => this.loadTemplates());
    }

    toEditorField(f, idx) {
        const ft = f.FieldType__c || 'テキスト';
        return {
            _key:           'field_' + idx + '_' + Date.now(),
            label:          f.Name || '',
            fieldType:      ft,
            isRequired:     f.IsRequired__c || false,
            picklistOptions: f.PicklistOptions__c || '',
            placeholder:    f.PlaceholderText__c || '',
            helpText:       f.HelpText__c || '',
            apiKey:         f.ApiKey__c || ('field_' + idx),
            showOptions:    ['選択（単一）','選択（複数）'].includes(ft)
        };
    }
}
