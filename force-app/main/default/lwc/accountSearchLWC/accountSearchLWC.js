import { LightningElement,track, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { RefreshEvent } from 'lightning/refresh';
import getAccountByName from '@salesforce/apex/AccountSearchHandler.searchAccountLookup';
import attachAccToLead from '@salesforce/apex/AccountSearchHandler.attachAccountToLead';
const columns = [
    { label: 'Account Name', fieldName: 'Name' },
    { label: 'Account Executive', fieldName: 'accountExecutiveName' },
    { label: 'Dev Solution Lead', fieldName: 'devSolutionsLeadName' }
    
];
export default class AccountSearchLWC extends LightningElement {
    // Current Lead Record Id from Lead Record Page
    @api recordId;
    
    selectedAccount = null;
    selectedAccAEName = null;
    selectedAccDevSolLeadName = null;

    @track accFlag = true;
    @track accountsList;
    @track columns = columns;
    
    //logic for clearing the selected account
    handleClear(){
        this.selectedAccount = null;
        this.selectedAccAEName = null;
        this.selectedAccDevSolLeadName = null;
        this.accFlag = true;
        this.accountsList = null;

    }
    
    //logic to set new change account values
    handleKeyChange(event){
        const searchString = event.target.value; 
        if(searchString.length > 2)  {
            getAccountByName({ searchTerm: searchString })
            .then(result => {
                if(result.length > 0){
                    this.accFlag = true;
                    //this.accountsList = result;
                    this.accountsList = result.map(account => ({
                        Id: account.Id,
                        Name: account.Name,
                        accountExecutiveName: account.Sales_Account_Executive__r ? account.Sales_Account_Executive__r.Name : '',
                        devSolutionsLeadName: account.Dev_Solutions_Lead__r ? account.Dev_Solutions_Lead__r.Name : ''
                    }));
                }
                else{
                    this.accFlag =false;
                }
            })
            .catch(error => {
                this.showToast(
                        'Error',
                        error.body.message,
                        'error'
                    );
                console.log('Error occured:- '+error.body.message);
            });
        }
        else{
            this.accountList = null;
            this.accFlag =false;
        }
    }

    handleAttach(){
        console.log('Selected Account: ' + this.selectedAccount);
        console.log('Lead Record Id: ' + this.recordId);
        //const accountName = this.selectedAccount;
        //console.log(JSON.stringify(accountName));
        //console.log(typeof accountName);
        if(this.selectedAccount){
            attachAccToLead({
                accName: this.selectedAccount,
                leadId: this.recordId
            })
            .then(result => {
                console.log('Account attached successfully');
                this.showToast(
                    'Success',
                    'Account attached successfully',
                    'success'
                );
                this.handleClear();
                this.dispatchEvent(new RefreshEvent());
            })
            .catch(error => {
                this.showToast(
                    'Error',
                    error.body.message,
                    'error'
                );
                console.log('Error occured:- '+error.body.message);
            });
        }
    }

    handleRowSelection(event){
        var selectedRows = event.detail.selectedRows;
        if (selectedRows.length > 0) {
            this.selectedAccount = selectedRows[0].Name;
            this.selectedAccAEName = selectedRows[0].accountExecutiveName;
            this.selectedAccDevSolLeadName = selectedRows[0].devSolutionsLeadName;
        }
        console.log('Selected Account: ' + this.selectedAccount);
    }

    // Reusable toast method
    showToast(title, message, variant) {

        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });

        this.dispatchEvent(evt);
    }
}
