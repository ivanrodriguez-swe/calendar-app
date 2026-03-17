import { LightningElement, api, wire } from 'lwc';
import {CurrentPageReference, NavigationMixin} from 'lightning/navigation';
import validateToken from '@salesforce/apex/TokenValidatorController.validateToken';

const TOKEN_PARAM = 'urlToken';
const RECORD_ID_PARAM = 'requestId';


export default class TokenValidator extends NavigationMixin(LightningElement) {
    @api defaultPageName = 'default';

    isValidated = false;
    error;
    recordId;
    _hasValidated = false;

    @wire(CurrentPageReference)
    handlePageReference(pageRef) {
        if (!pageRef || this._hasValidated) {
            return;
        }
        this._hasValidated = true; // CRITICAL: Add this line!

        const urlToken = pageRef.state?.[TOKEN_PARAM];
        console.log(`Token ${urlToken}`);

        this.recordId = pageRef.state?.[RECORD_ID_PARAM];
        console.log(`Record Id ${this.recordId}`);

        // Only proceed if we have both values
        if (urlToken && this.recordId) {
            console.log(`Before validation`);
            this.validateAccess(urlToken, this.recordId);
        } else {
            console.log('Missing token or recordId, redirecting...');
            this.redirectToDefaultPage();
        }
    }

    async validateAccess(urlToken, recordId) {
        console.log(`In Validate Access method Token: ${urlToken} and RecordId: ${recordId}`);

        if (!urlToken || !recordId) {
            console.log(`Before redirecting to Default Page`);
            this.redirectToDefaultPage();
            return;
        }

        try {
            console.log('Calling Apex validateToken method...');
            
            // Create clean string values
            const cleanToken = String(urlToken).trim();
            const cleanRecordId = String(recordId).trim();
            
            // Log what we're sending
            console.log('Sending to Apex - token:', cleanToken, 'recordId:', cleanRecordId);
            // Create a new object with guaranteed string values
            const requestData = Object.assign({}, {
                urlToken: cleanToken,
                recordId: cleanRecordId
            });
            
            const result = await validateToken({
                request: requestData
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
                this.redirectToDefaultPage();
            }
        } catch (err) {
            console.error(`Error received:`, err);
            console.error('Error message:', err.message);
            this.redirectToDefaultPage();
        }
    }

    redirectToDefaultPage() {
        console.log(`Redirect called to page: ${this.defaultPageName}`);
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                name: this.defaultPageName
            }
        }); // Remove the extra 'true' parameter
    }
}