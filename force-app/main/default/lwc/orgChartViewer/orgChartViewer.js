import { LightningElement, track } from 'lwc';
import getAllOrgUnits from '@salesforce/apex/OrgChartController.getAllOrgUnits';
import getAllMembers  from '@salesforce/apex/OrgChartController.getAllMembers';

export default class OrgChartViewer extends LightningElement {
    @track allUnits   = [];
    @track allMembers = [];
    @track selectedUnit  = null;
    @track unitMembers   = [];
    @track isLoading     = true;

    connectedCallback() { this.loadOrgData(); }

    async loadOrgData() {
        try {
            this.isLoading = true;
            const [units, members] = await Promise.all([getAllOrgUnits(), getAllMembers()]);
            this.allUnits   = units   ?? [];
            this.allMembers = members ?? [];
        } catch (e) {
            console.error('Org chart load error:', e);
        } finally {
            this.isLoading = false;
        }
    }

    get rootUnits() { return this.buildTree(null); }

    buildTree(parentId) {
        return this.allUnits
            .filter(u => (u.ParentUnit__c ?? null) === parentId)
            .map(u => ({
                ...u,
                children:    this.buildTree(u.Id),
                memberCount: this.allMembers.filter(m => m.OrgUnit__c === u.Id).length
            }));
    }

    handleUnitSelect(event) {
        this.selectedUnit = this.allUnits.find(u => u.Id === event.detail.unitId) ?? null;
        this.unitMembers  = this.allMembers.filter(m => m.OrgUnit__c === this.selectedUnit?.Id);
    }

    clearSelection() {
        this.selectedUnit = null;
        this.unitMembers  = [];
    }
}
