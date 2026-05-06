import { LightningElement } from 'lwc';
import getAppointmentRequestInfo from '@salesforce/apex/VolunteerAvailabilityController.getAppointmentRequestInfo';

export default class ReferenceRequest extends LightningElement {
    recordId;
    referenceName;

    showAppointmentScheduler = false;
    showReferenceForm = false;
    showFlowConfirmation = false;
    showNoActionCanBeTaken = false;
    showOptions = false;

    handleValidated(event){
        this.recordId = event.detail.recordId;
        if(this.recordId){
            getAppointmentRequestInfo({ requestId: this.recordId })
                .then(result => {
                    if (result) {
                        if (result.status === 'Reserved' || result.status === 'Closed') {
                            this.showNoActionCanBeTaken = true;
                            this.showContent = false;
                        }else{
                             this.referenceName = result.referenceName;
                             this.showNoActionCanBeTaken = false;
                             this.showOptions = true;
                        }
                    }
                })
                .catch(() => {
                    console.log(`There was an  error when accessing the Appointment request`)
                });
        }
    }

    get showContent(){
        return this.showOptions && !this.showNoActionCanBeTaken;
    }

    get showChoiceSection(){
        return this.showContent && !this.showAppointmentScheduler && 
               !this.showReferenceForm && !this.showFlowConfirmation && !this.showNoActionCanBeTaken;
    }

    get flowInputVariables(){
        return [{name:'recordId', type:'String', value:this.recordId}];
    }

    handleLeftButton(){
        this.showReferenceForm = true;
    }

    handleRightButton(){
        this.showAppointmentScheduler = true;
    }

    handleFlowStatusChange(event){
        if(event.detail.status === 'FINISHED' || event.detail.status === 'FINISHED_SCREEN'){
            this.showReferenceForm = false;
            this.showFlowConfirmation = true;
        }
    }

}