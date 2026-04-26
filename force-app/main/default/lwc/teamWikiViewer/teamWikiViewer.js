import { LightningElement, api, track, wire } from 'lwc';
import getWikisByOrgUnit from '@salesforce/apex/TeamWikiController.getWikisByOrgUnit';
import getWikiPages from '@salesforce/apex/TeamWikiController.getWikiPages';
import getWikiPageDetail from '@salesforce/apex/TeamWikiController.getWikiPageDetail';
import savePage from '@salesforce/apex/TeamWikiController.savePage';

export default class TeamWikiViewer extends LightningElement {
    @api orgUnitId;
    @api canEdit = false;

    @track wikis = [];
    @track pages = [];
    @track selectedPage = null;
    @track isEditing = false;
    @track isLoading = false;
    @track isSaving = false;

    wikiId = null;
    wikiName = '';
    homeContent = '';

    editTitle = '';
    editContent = '';
    editTags = '';
    editStatus = '公開';
    editSummary = '';
    activePageId = null;

    statusOptions = [
        { label: '下書き', value: '下書き' },
        { label: '公開', value: '公開' }
    ];

    connectedCallback() {
        if (this.orgUnitId) this.loadWikis();
    }

    loadWikis() {
        this.isLoading = true;
        getWikisByOrgUnit({ orgUnitId: this.orgUnitId })
            .then(data => {
                this.wikis = data;
                if (data.length > 0) {
                    this.wikiId      = data[0].Id;
                    this.wikiName    = data[0].Name;
                    this.homeContent = data[0].HomePageContent__c;
                    this.loadPages();
                } else {
                    this.isLoading = false;
                }
            })
            .catch(() => { this.isLoading = false; });
    }

    loadPages() {
        getWikiPages({ wikiId: this.wikiId })
            .then(data => {
                this.pages    = data;
                this.isLoading = false;
            })
            .catch(() => { this.isLoading = false; });
    }

    get pageTree() {
        const roots = this.pages.filter(p => !p.ParentPage__c).map(p => ({
            ...p,
            activeCss: p.Id === this.activePageId ? 'font-weight: bold; color: #0070d2;' : '',
            children: this.pages.filter(c => c.ParentPage__c === p.Id).map(c => ({
                ...c,
                activeCss: c.Id === this.activePageId ? 'font-weight: bold; color: #0070d2;' : ''
            }))
        }));
        return roots;
    }

    get tagList() {
        if (!this.selectedPage?.Tags__c) return [];
        return this.selectedPage.Tags__c.split(',').map(t => t.trim()).filter(t => t);
    }

    handleSelectPage(event) {
        const id = event.currentTarget.dataset.id;
        this.activePageId = id;
        this.isEditing    = false;
        this.isLoading    = true;
        getWikiPageDetail({ pageId: id })
            .then(data => {
                this.selectedPage = data;
                this.isLoading    = false;
            })
            .catch(() => { this.isLoading = false; });
    }

    handleNewPage() {
        this.selectedPage = null;
        this.activePageId = null;
        this.editTitle   = '';
        this.editContent = '';
        this.editTags    = '';
        this.editStatus  = '下書き';
        this.editSummary = '新規作成';
        this.isEditing   = true;
    }

    handleEdit() {
        this.editTitle   = this.selectedPage.Name;
        this.editContent = this.selectedPage.Content__c || '';
        this.editTags    = this.selectedPage.Tags__c || '';
        this.editStatus  = this.selectedPage.PageStatus__c;
        this.editSummary = '';
        this.isEditing   = true;
    }

    handleCancelEdit() {
        this.isEditing = false;
    }

    handleTitleChange(e)   { this.editTitle   = e.target.value; }
    handleContentChange(e) { this.editContent = e.target.value; }
    handleTagsChange(e)    { this.editTags    = e.target.value; }
    handleStatusChange(e)  { this.editStatus  = e.detail.value; }
    handleSummaryChange(e) { this.editSummary = e.target.value; }

    handleSave() {
        if (!this.editTitle.trim()) {
            alert('タイトルを入力してください。');
            return;
        }
        this.isSaving = true;
        savePage({
            pageData: {
                id:          this.selectedPage ? this.selectedPage.Id : null,
                wikiId:      this.wikiId,
                title:       this.editTitle,
                content:     this.editContent,
                pageStatus:  this.editStatus,
                tags:        this.editTags,
                editSummary: this.editSummary
            }
        })
            .then(savedId => {
                this.isEditing = false;
                this.isSaving  = false;
                this.loadPages();
                this.activePageId = savedId;
                return getWikiPageDetail({ pageId: savedId });
            })
            .then(data => { this.selectedPage = data; })
            .catch(() => { this.isSaving = false; });
    }
}
