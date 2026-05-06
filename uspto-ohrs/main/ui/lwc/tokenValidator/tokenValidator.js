import { LightningElement, api, wire } from 'lwc';
import {CurrentPageReference, NavigationMixin} from 'lightning/navigation';
import validateToken from '@salesforce/apex/TokenValidatorController.validateToken';

const TOKEN_PARAM = 'urlToken';
const RECORD_ID_PARAM = 'requestId';


export default class TokenValidator extends NavigationMixin(LightningElement) {
    @api defaultPageName = 'Default__c';
    @api disableRedirect = false;  // Controls whether redirects happen

    isValidated = false;
    error;
    recordId;
    _hasValidated = false;
    
    @wire(CurrentPageReference)
    handlePageReference(pageRef) {
        if (!pageRef || this._hasValidated) {
            return;
        }
        this._hasValidated = true;

        const urlToken = pageRef.state?.[TOKEN_PARAM];
        console.log(`Token ${urlToken}`);

        this.recordId = pageRef.state?.[RECORD_ID_PARAM];
        console.log(`Record Id ${this.recordId}`);

        // Only proceed if we have both values
        if (urlToken && this.recordId) {
            console.log(`Before validation`);
            this.validateAccess(urlToken, this.recordId);
        } else {
            console.log('Missing token or recordId');
            if (!this.disableRedirect) { 
                console.log('Redirecting...');
                this.redirectToDefaultPage();
            } else {
                console.log('Redirect disabled - staying on page');
            }
        }
    }

    async validateAccess(urlToken, recordId) {
        console.log(`In Validate Access method Token: ${urlToken} and RecordId: ${recordId}`);

        if (!urlToken || !recordId) {
            console.log(`Missing parameters`);
            if (!this.disableRedirect) { 
                console.log(`Before redirecting to Default Page`);
                this.redirectToDefaultPage();
            }
            return;
        }

        try {
            console.log('Calling Apex validateToken method...');
            
            // Create clean string values
            const cleanToken = String(urlToken).trim();
            const cleanRecordId = String(recordId).trim();
            
            // Log what we're sending
            console.log('Sending to Apex - token:', cleanToken, 'recordId:', cleanRecordId);
            
            const result = await validateToken({
                urlToken : cleanToken,
                recordId : cleanRecordId
            });

            console.log(`Here is the result received: ${result}`);

            if (result && result === 'isValid') {
                this.isValidated = true;
                this.dispatchEvent(new CustomEvent('validated', {
                    detail: { recordId: this.recordId },
                    bubbles: true,
                    composed: true
                }));
            } else {
                if (!this.disableRedirect) {  
                    this.redirectToDefaultPage();
                } else {
                    console.log('Validation failed but redirect disabled');
                }
            }
        } catch (err) {
            console.error(`Error received:`, err);
            console.error('Error message:', err.message);
            if (!this.disableRedirect) {  
                this.redirectToDefaultPage();
            } else {
                console.log('Error occurred but redirect disabled');
            }
        }
    }

    redirectToDefaultPage() {
        if (this.disableRedirect) { 
            console.log('Redirect disabled - aborting redirect');
            return;
        }
        
        console.log(`Redirect called to page: ${this.defaultPageName}`);
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                name: this.defaultPageName
            }
        });
    }
}