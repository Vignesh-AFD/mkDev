import { LightningElement, track, wire } from 'lwc';

import searchUsers from '@salesforce/apex/UserSalesInfoController.searchUsers';
import getUserDetails from '@salesforce/apex/UserSalesInfoController.getUserDetails';
import updateUserSalesInfo from '@salesforce/apex/UserSalesInfoController.updateUserSalesInfo';

import { ShowToastEvent } from 'lightning/platformShowToastEvent';

//import USER_OBJECT from '@salesforce/schema/User';

import SALES_VERTICAL_FIELD from '@salesforce/schema/User.Sales_Vertical__c';
import SALES_REGION_FIELD from '@salesforce/schema/User.Sales_Region__c';

//import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import { getPicklistValues } from 'lightning/uiObjectInfoApi';

export default class UserSalesEditor extends LightningElement {

    @track users = [];

    searchTerm = '';

    selectedUserId;

    salesVertical;
    salesRegion;

    originalVertical;
    originalRegion;

    salesVerticalOptions = [];
    salesRegionOptions = [];

    // Get User Object Info
    /*@wire(getObjectInfo, { objectApiName: USER_OBJECT })
    userObjectInfo;*/

    // Sales Vertical Picklist
    @wire(getPicklistValues, {
        recordTypeId: '012000000000000AAA', //'$userObjectInfo.data.defaultRecordTypeId',
        fieldApiName: SALES_VERTICAL_FIELD
    })
    verticalPicklistValues({ data, error }) {
        if(data) {
            this.salesVerticalOptions = data.values.map(item => ({
                label: item.label,
                value: item.value
            }));
            console.log('Vertical Picklist Values:', this.salesVerticalOptions);
        }
        else if(error) {
            console.error(error);
        }
    }

    // Sales Region Picklist
    @wire(getPicklistValues, {
        recordTypeId: '012000000000000AAA', //'$userObjectInfo.data.defaultRecordTypeId',
        fieldApiName: SALES_REGION_FIELD
    })
    regionPicklistValues({ data, error }) {
        if(data) {
            this.salesRegionOptions = data.values.map(item => ({
                label: item.label,
                value: item.value
            }));
            console.log('Region Picklist Values:', this.salesRegionOptions);
        }
        else if(error) {
            console.error(error);
        }
    }

    handleSearchChange(event) {

        this.searchTerm = event.target.value;
        //console.log('Search Term:', this.searchTerm);

        if(this.searchTerm.length >= 2) {

            searchUsers({ searchTerm: this.searchTerm })
                .then(result => {
                    this.users = result;
                })
                .catch(error => {
                    console.error(error);
                });
        }
        else {
            this.users = [];
        }
    }

    handleUserSelect(event) {
        this.selectedUserId = event.currentTarget.dataset.id;
        console.log('Selected User ID:', this.selectedUserId);
        const selectedName = event.currentTarget.dataset.name;
        this.searchTerm = selectedName;
        console.log('Selected User Name:', selectedName);

        this.users = [];

        getUserDetails({ userId: this.selectedUserId })
            .then(result => {
                console.log('User Details:', result);

                this.salesVertical = result.Sales_Vertical__c || '';
                this.salesRegion = result.Sales_Region__c || '';

                this.originalVertical = this.salesVertical;
                this.originalRegion = this.salesRegion;
            })
            .catch(error => {
                console.error(error);
            });
    }

    get hasUsers() {
        return this.users && this.users.length > 0;
    }

    handleVerticalChange(event) {
        this.salesVertical = event.detail.value;
    }

    handleRegionChange(event) {
        this.salesRegion = event.detail.value;
    }

    handleSave() {

        updateUserSalesInfo({
            userId: this.selectedUserId,
            salesVertical: this.salesVertical,
            salesRegion: this.salesRegion
        })
        .then(() => {

            this.originalVertical = this.salesVertical;
            this.originalRegion = this.salesRegion;

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'User updated successfully',
                    variant: 'success'
                })
            );

            this.resetComponent();
        })
        .catch(error => {

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: error.body.message,
                    variant: 'error'
                })
            );
        });
    }

    resetComponent() {
        this.searchTerm = '';
        this.selectedUserId = null;
        this.users = [];

        this.salesVertical = '';
        this.salesRegion = '';

        this.originalVertical = '';
        this.originalRegion = '';
    }

    handleCancel() {

        this.salesVertical = this.originalVertical;
        this.salesRegion = this.originalRegion;
        this.resetComponent();
    }
}