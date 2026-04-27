import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import generateTemplateCsv  from '@salesforce/apex/BulkNotificationController.generateTemplateCsv';
import parseCsv             from '@salesforce/apex/BulkNotificationController.parseCsv';
import renderPreview        from '@salesforce/apex/BulkNotificationController.renderPreview';
import sendBulkNotifications from '@salesforce/apex/BulkNotificationController.sendBulkNotifications';
import getMemberTypeOptions  from '@salesforce/apex/BulkNotificationController.getMemberTypeOptions';

export default class BulkNotificationAdmin extends LightningElement {
    @track currentStep      = 1;
    @track subjectTemplate  = '';
    @track bodyTemplate     = '';
    @track memberTypeFilter = '';
    @track memberTypeOptions = [{ label: '全会員', value: '' }];
    @track customFields     = [];
    @track channelEmail     = true;
    @track channelSlack     = false;

    @track isGenerating     = false;
    @track isParsing        = false;
    @track isPreviewLoading = false;
    @track isSending        = false;

    @track csvDownloaded    = false;
    @track parsedRows       = [];
    @track previewItems     = [];
    @track sendResult       = null;

    @track step1Error = '';
    @track step2Error = '';
    @track step3Error = '';
    @track step4Error = '';
    @track step5Error = '';

    _fieldIdSeq = 0;

    connectedCallback() {
        getMemberTypeOptions()
            .then(opts => { this.memberTypeOptions = opts; })
            .catch(() => {});
    }

    // ---- Computed ----

    get isStep1() { return this.currentStep === 1; }
    get isStep2() { return this.currentStep === 2; }
    get isStep3() { return this.currentStep === 3; }
    get isStep4() { return this.currentStep === 4; }
    get isStep5() { return this.currentStep === 5; }

    get step1Done() { return this.currentStep > 1; }
    get step2Done() { return this.currentStep > 2; }
    get step3Done() { return this.currentStep > 3; }
    get step4Done() { return this.currentStep > 4; }

    get stepClass1() { return this._stepClass(1); }
    get stepClass2() { return this._stepClass(2); }
    get stepClass3() { return this._stepClass(3); }
    get stepClass4() { return this._stepClass(4); }
    get stepClass5() { return this._stepClass(5); }

    _stepClass(n) {
        if (this.currentStep > n) return 'slds-progress__item slds-is-completed';
        if (this.currentStep === n) return 'slds-progress__item slds-is-active';
        return 'slds-progress__item';
    }

    get progressPercent() { return (this.currentStep - 1) * 25; }
    get progressStyle()   { return `width: ${this.progressPercent}%`; }

    get parsedRowCount() { return this.parsedRows?.length ?? 0; }
    get noParsedRows()   { return !this.parsedRows || this.parsedRows.length === 0; }

    get channelSummary() {
        const parts = [];
        if (this.channelEmail) parts.push('メール');
        if (this.channelSlack) parts.push('Slack');
        return parts.length > 0 ? parts.join(' + ') : '未選択';
    }

    // ---- Step 1 handlers ----

    handleSubjectChange(event) { this.subjectTemplate = event.target.value; }
    handleBodyChange(event)    { this.bodyTemplate    = event.target.value; }
    handleMemberTypeChange(event) { this.memberTypeFilter = event.detail.value; }
    handleChannelEmailChange(event) { this.channelEmail = event.target.checked; }
    handleChannelSlackChange(event) { this.channelSlack = event.target.checked; }

    handleAddCustomField() {
        this.customFields = [...this.customFields, { id: ++this._fieldIdSeq, name: '' }];
    }

    handleRemoveCustomField(event) {
        const idx = parseInt(event.currentTarget.dataset.idx, 10);
        this.customFields = this.customFields.filter((_, i) => i !== idx);
    }

    handleCustomFieldChange(event) {
        const idx = parseInt(event.currentTarget.dataset.idx, 10);
        this.customFields = this.customFields.map((f, i) =>
            i === idx ? { ...f, name: event.target.value } : f
        );
    }

    handleStep1Next() {
        this.step1Error = '';
        if (!this.subjectTemplate) { this.step1Error = '件名テンプレートを入力してください。'; return; }
        if (!this.bodyTemplate)    { this.step1Error = '本文テンプレートを入力してください。'; return; }
        if (!this.channelEmail && !this.channelSlack) {
            this.step1Error = '送信チャンネルを少なくとも1つ選択してください。'; return;
        }
        this.currentStep = 2;
    }

    // ---- Step 2 handlers ----

    async handleDownloadCsv() {
        this.isGenerating = true;
        this.step2Error   = '';
        try {
            const customFieldNames = this.customFields
                .map(f => f.name)
                .filter(n => n && n.trim());
            const csv = await generateTemplateCsv({
                customFields: customFieldNames,
                memberTypeFilter: this.memberTypeFilter || null
            });
            this._triggerCsvDownload(csv, 'bulk_notification_template.csv');
            this.csvDownloaded = true;
        } catch (e) {
            this.step2Error = e?.body?.message || 'CSV生成に失敗しました。';
        } finally {
            this.isGenerating = false;
        }
    }

    _triggerCsvDownload(content, filename) {
        const blob = new Blob([content], { type: 'text/csv;charset=utf-8;' });
        const url  = URL.createObjectURL(blob);
        const a    = document.createElement('a');
        a.href     = url;
        a.download = filename;
        a.style.display = 'none';
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
    }

    handleStep2Next() {
        this.currentStep = 3;
    }

    // ---- Step 3 handlers ----

    handleFileChange(event) {
        const file = event.target.files[0];
        if (!file) return;

        this.step3Error = '';
        this.isParsing  = true;
        this.parsedRows = [];

        const reader = new FileReader();
        reader.onload = async (e) => {
            try {
                const text = e.target.result;
                const rows = await parseCsv({ csvContent: text });
                this.parsedRows = rows;
                if (!rows || rows.length === 0) {
                    this.step3Error = 'データが見つかりませんでした。CSVの形式を確認してください。';
                }
            } catch (err) {
                this.step3Error = err?.body?.message || 'CSVの解析に失敗しました。';
            } finally {
                this.isParsing = false;
            }
        };
        reader.onerror = () => {
            this.step3Error = 'ファイルの読み込みに失敗しました。';
            this.isParsing  = false;
        };
        // Excel保存CSVはShift-JISの場合があるため UTF-8 → fallback
        reader.readAsText(file, 'UTF-8');
    }

    handleStep3Next() {
        if (!this.parsedRows || this.parsedRows.length === 0) {
            this.step3Error = 'CSVファイルをアップロードしてください。';
            return;
        }
        this.currentStep = 4;
        this._loadPreview();
    }

    // ---- Step 4 handlers ----

    async _loadPreview() {
        this.isPreviewLoading = true;
        this.step4Error       = '';
        try {
            this.previewItems = await renderPreview({
                subjectTemplate: this.subjectTemplate,
                bodyTemplate:    this.bodyTemplate,
                rowsJson:        JSON.stringify(this.parsedRows)
            });
        } catch (e) {
            this.step4Error = e?.body?.message || 'プレビューの生成に失敗しました。';
        } finally {
            this.isPreviewLoading = false;
        }
    }

    handleStep4Next() {
        this.currentStep = 5;
    }

    // ---- Step 5 handlers ----

    async handleSend() {
        this.isSending  = true;
        this.step5Error = '';
        try {
            const channels = [];
            if (this.channelEmail) channels.push('email');
            if (this.channelSlack) channels.push('slack');

            this.sendResult = await sendBulkNotifications({
                subjectTemplate: this.subjectTemplate,
                bodyTemplate:    this.bodyTemplate,
                rowsJson:        JSON.stringify(this.parsedRows),
                channels:        channels.join(',')
            });

            if (this.sendResult.successCount > 0) {
                this.dispatchEvent(new ShowToastEvent({
                    title:   '送信完了',
                    message: `${this.sendResult.successCount} 件の通知を送信しました。`,
                    variant: 'success'
                }));
            }
        } catch (e) {
            this.step5Error = e?.body?.message || '送信に失敗しました。';
        } finally {
            this.isSending = false;
        }
    }

    handleReset() {
        this.currentStep     = 1;
        this.subjectTemplate = '';
        this.bodyTemplate    = '';
        this.memberTypeFilter = '';
        this.customFields    = [];
        this.channelEmail    = true;
        this.channelSlack    = false;
        this.csvDownloaded   = false;
        this.parsedRows      = [];
        this.previewItems    = [];
        this.sendResult      = null;
        this.step1Error = this.step2Error = this.step3Error = this.step4Error = this.step5Error = '';
    }

    handleBack() {
        if (this.currentStep > 1) this.currentStep--;
    }
}
