import { LightningElement, track } from 'lwc';
import processFile from '@salesforce/apex/AppointmentRequestController.processFile';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class AppointmentRequestUploader extends LightningElement {
    @track showModal = false;
    @track selectedFile;
    @track uploading = false;
    @track fileName = '';

    handleOpenModal() {
        this.showModal = true;
    }

    handleCloseModal() {
        this.showModal = false;
        this.selectedFile = null;
        this.fileName = '';
        const fileInput = this.template.querySelector('lightning-input[type="file"]');
        if (fileInput) {
            fileInput.value = '';
        }
    }

    handleFileChange(event) {
        const file = event.target.files[0];
        if (file) {
            if (file.type !== 'text/csv' && !file.name.endsWith('.csv')) {
                this.showToast('Error', 'Please upload a CSV file', 'error');
                return;
            }
            this.selectedFile = file;
            this.fileName = file.name;
        }
    }

    async handleUpload() {
        if (!this.selectedFile) {
            this.showToast('Error', 'Please select a CSV file', 'error');
            return;
        }

        this.uploading = true;

        try {
            const fileContent = await this.readFileContent(this.selectedFile);
            
            const result = await processFile({
                fileContent: fileContent
            });

            if (result.success) {
                this.showToast('Success', 
                    `${result.selecteesCreated} Selectee(s) and ${result.requestsCreated} Appointment Request(s) created successfully.`, 
                    'success');
                this.handleCloseModal();
                
                this.dispatchEvent(new CustomEvent('uploadsuccess'));
            } else {
                this.showToast('Error', result.message, 'error');
            }
        } catch (error) {
            this.showToast('Error', 
                'Error processing file: ' + (error.body?.message || error.message || 'Unknown error'), 
                'error');
        } finally {
            this.uploading = false;
        }
    }

    readFileContent(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = (e) => {
                resolve(e.target.result);
            };
            reader.onerror = (error) => {
                reject(error);
            };
            reader.readAsText(file);
        });
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(event);
    }
}
