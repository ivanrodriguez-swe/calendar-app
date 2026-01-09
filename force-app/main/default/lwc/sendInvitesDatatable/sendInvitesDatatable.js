import { LightningElement, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getNewAppointmentRequests from '@salesforce/apex/AppointmentRequestController.getNewAppointmentRequests';
import sendInviteEmails from '@salesforce/apex/AppointmentRequestController.sendInviteEmails';

const COLUMNS = [
    { label: 'Reference Name', fieldName: 'Reference_First_Name__c', type: 'text' },
    { label: 'Reference Email', fieldName: 'Reference_Email__c', type: 'email' },
    { label: 'Selectee', fieldName: 'SelecteeName', type: 'text' },
    { label: 'Status', fieldName: 'Status__c', type: 'text' },
    { label: 'Created Date', fieldName: 'CreatedDate', type: 'date', typeAttributes: {
        year: 'numeric',
        month: 'short',
        day: '2-digit',
        hour: '2-digit',
        minute: '2-digit'
    }}
];

export default class SendInvitesDatatable extends LightningElement {
    columns = COLUMNS;
    @track data = [];
    @track selectedIds = [];
    @track isSending = false;
    wiredResult;

    @wire(getNewAppointmentRequests)
    wiredAppointmentRequests(result) {
        this.wiredResult = result;
        if (result.data) {
            // Flatten the Selectee relationship for datatable display
            this.data = result.data.map(record => ({
                ...record,
                SelecteeName: record.Selectee__r ? record.Selectee__r.Name : ''
            }));
        } else if (result.error) {
            this.showToast('Error', 'Error loading appointment requests: ' + result.error.body?.message, 'error');
            this.data = [];
        }
    }

    get hasRecords() {
        return this.data && this.data.length > 0;
    }

    get selectedCount() {
        return this.selectedIds.length;
    }

    get isSendDisabled() {
        return this.selectedIds.length === 0 || this.isSending;
    }

    get sendButtonLabel() {
        if (this.isSending) {
            return 'Sending...';
        }
        return this.selectedIds.length > 0 
            ? `Send Invites (${this.selectedIds.length})` 
            : 'Send Invites';
    }

    get recordCountLabel() {
        const count = this.data.length;
        return `${count} record${count !== 1 ? 's' : ''} with "New" status`;
    }

    handleRowSelection(event) {
        const selectedRows = event.detail.selectedRows;
        this.selectedIds = selectedRows.map(row => row.Id);
    }

    async handleSendInvites() {
        if (this.selectedIds.length === 0) {
            this.showToast('Warning', 'Please select at least one record', 'warning');
            return;
        }

        this.isSending = true;

        try {
            const result = await sendInviteEmails({ requestIds: this.selectedIds });

            if (result.success) {
                this.showToast('Success', `${result.emailsSent} invite(s) sent`, 'success');
                
                if (result.errors && result.errors.length > 0) {
                    this.showToast('Note', result.errors.join('; '), 'warning');
                }

                // Clear selection and refresh data
                this.selectedIds = [];
                await refreshApex(this.wiredResult);
            } else {
                const errorMsg = result.errors && result.errors.length > 0 
                    ? result.errors.join('; ') 
                    : 'Failed to send emails';
                this.showToast('Error', errorMsg, 'error');
            }
        } catch (error) {
            this.showToast('Error', error.body?.message || 'An error occurred', 'error');
        } finally {
            this.isSending = false;
        }
    }

    async handleRefresh() {
        await refreshApex(this.wiredResult);
        this.showToast('Refreshed', 'Data has been refreshed', 'success');
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title,
            message,
            variant
        }));
    }
}

