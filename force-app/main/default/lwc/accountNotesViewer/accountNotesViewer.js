import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getRelatedNotes from '@salesforce/apex/AccountNotesController.getRelatedNotes';

const DATE_FIELDS = ['createdDate', 'contentModifiedDate'];

export default class AccountNotesViewer extends NavigationMixin(LightningElement) {
    @api recordId;
    @track notes = [];
    @track isLoading = true;
    @track error;
    @track sortBy = 'createdDate';  
    @track sortDirection = 'desc';
    currentPage = 1;
    pageSize = 10;

    columns = [
        {
            label: '#',
            fieldName: 'index',
            type: 'number',
            sortable: false,
            initialWidth: 60
        },
        {
            label: 'Note Title',
            fieldName: 'noteLink',
            type: 'url',
            typeAttributes: {
                label: { fieldName: 'title' },
                target: '_blank'
            },
            sortable: true
        },
        {
            label: 'Text Preview',
            fieldName: 'textPreview',
            type: 'text',
            sortable: true,
            initialWidth: 300,
            wrapText: false,
            cellAttributes: { class: 'slds-cell-wrap truncated-text' }
        },
        { label: 'Created By', fieldName: 'createdBy', type: 'text', sortable: true },
        {
            label: 'Created Date',
            fieldName: 'createdDate',
            type: 'date',
            typeAttributes: {
                year: 'numeric',
                month: 'short',
                day: '2-digit'
            },
            sortable: true
        },
        {
            label: 'Last Modified',
            fieldName: 'contentModifiedDate',
            type: 'date',
            typeAttributes: {
                year: 'numeric',
                month: 'short',
                day: '2-digit'
            },
            sortable: true
        },
        { label: 'Last Modified By', fieldName: 'lastModifiedBy', type: 'text', sortable: true }
    ];

    connectedCallback() {
        this.fetchNotes();
    }

    get paginatedNotes() {
        const startIndex = (this.currentPage - 1) * this.pageSize;
        return this.notes
            .slice(startIndex, startIndex + this.pageSize)
            .map((note, index) => ({
                ...note,
                index: startIndex + index + 1
            }));
    }

    get showPaginationControls() {
        return this.totalPages > 1;
    }

    get totalRecords() {
        return this.notes.length;
    }

    get totalPages() {
        return Math.ceil(this.totalRecords / this.pageSize);
    }

    get isFirstPage() {
        return this.currentPage === 1;
    }

    get isLastPage() {
        return this.currentPage >= this.totalPages;
    }

    get pageStart() {
        return (this.currentPage - 1) * this.pageSize + 1;
    }

    get pageEnd() {
        return Math.min(this.currentPage * this.pageSize, this.totalRecords);
    }

fetchNotes() {
    this.isLoading = true;
    getRelatedNotes({ accountId: this.recordId })
        .then(result => {
            this.notes = result.map(note => {
                // Parse the original dates from Salesforce (UTC)
                const createdDate = new Date(note.createdDate);
                const contentModifiedDate = new Date(note.contentModifiedDate);

                // Create new dates using UTC components adjusted to local timezone
                return {
                    ...note,
                    createdDate: new Date(
                        createdDate.getUTCFullYear(),
                        createdDate.getUTCMonth(),
                        createdDate.getUTCDate()
                    ),
                    contentModifiedDate: new Date(
                        contentModifiedDate.getUTCFullYear(),
                        contentModifiedDate.getUTCMonth(),
                        contentModifiedDate.getUTCDate()
                    ),
                    noteLink: `/lightning/r/ContentNote/${note.contentDocumentId}/view`
                };
            });
            this.sortNotes();
            this.error = null;
        })
        .catch(error => {
            this.error = error.body?.message || 'Error loading notes';
            this.notes = [];
        })
        .finally(() => {
            this.isLoading = false;
        });
}

    sortNotes() {
        const isReverse = this.sortDirection === 'desc' ? -1 : 1;
        this.notes = [...this.notes.sort((a, b) => {
            let valA = this.sortBy === 'noteLink' ? a.title : a[this.sortBy];
            let valB = this.sortBy === 'noteLink' ? b.title : b[this.sortBy];


            if (DATE_FIELDS.includes(this.sortBy)) {
                return (valA.getTime() - valB.getTime()) * isReverse;
            }

            valA = typeof valA === 'string' ? valA.toLowerCase() : valA;
            valB = typeof valB === 'string' ? valB.toLowerCase() : valB;

            return valA > valB ? isReverse : valA < valB ? -isReverse : 0;
        })];
    }

    handleSort(event) {
        const { fieldName, sortDirection } = event.detail;
        this.sortBy = fieldName;
        this.sortDirection = sortDirection;
        this.sortNotes();
    }

    handlePrevious() {
        if (this.currentPage > 1) this.currentPage--;
    }

    handleNext() {
        if (this.currentPage < this.totalPages) this.currentPage++;
    }

    handleFirst() {
        this.currentPage = 1;
    }

    handleLast() {
        this.currentPage = this.totalPages;
    }
}