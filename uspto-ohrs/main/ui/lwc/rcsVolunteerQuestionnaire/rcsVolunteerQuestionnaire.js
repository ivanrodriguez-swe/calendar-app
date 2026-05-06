import { LightningElement, api, wire } from 'lwc';
import USER_ID from '@salesforce/user/Id';
import { getRecord } from 'lightning/uiRecordApi';
import hasAccessQuestionnaire from '@salesforce/customPermission/Access_RCS_Questionnaires_Forms';

// Import field references
import VOLUNTEER_FIELD from '@salesforce/schema/Appointment_Request__c.Volunteer__c';
import STATUS_FIELD from '@salesforce/schema/Appointment_Request__c.Status__c';
import REF_FIRST_NAME_FIELD from '@salesforce/schema/Appointment_Request__c.Reference_First_Name__c';
import REF_LAST_NAME_FIELD from '@salesforce/schema/Appointment_Request__c.Reference_Last_Name__c';

const FIELDS = [
    VOLUNTEER_FIELD,
    STATUS_FIELD,
    REF_FIRST_NAME_FIELD,
    REF_LAST_NAME_FIELD
];

export default class RcsVolunteerQuestionnaire extends LightningElement {
    @api recordId;
    showForm = false;
    showConfirmation = false;
    currentUserId = USER_ID;

    // Wire getRecord for the appointment request fields
    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    record;

    get canSubmitForm() {
        const volunteerId = this.record.data?.fields?.Volunteer__c?.value;
        const status = this.record.data?.fields?.Status__c?.value;

        //Check if volunteer is the current users 
        if (volunteerId && volunteerId === this.currentUserId && (status === 'Reserved')) {
            return true;
        }
        
        if(hasAccessQuestionnaire && (status === 'Reserved')) {
            return true;
        }           

        return false;   
    }

    
    // Flow input variables getter
    get flowInputVariables() {
        return [
            {
                name: 'recordId',
                type: 'String',
                value: this.recordId
            }
        ];
    }

    // Start form handler
    handleStartForm() {
        this.showForm = true;
        this.showConfirmation = false;
    }

    
    // Flow status change handler
    handleFlowStatusChange(event) {
        const status = event?.detail?.status;
        if (!status) {
            return;
        }
        // Consider FINISHED and FINISHED_SCREEN as completion
        if (status === 'FINISHED' || status === 'FINISHED_SCREEN') {
            this.showForm = false;
            this.showConfirmation = true;
        }
    }




}