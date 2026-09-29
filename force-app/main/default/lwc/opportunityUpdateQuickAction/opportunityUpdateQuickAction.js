import { LightningElement, api, wire } from 'lwc';
import getData from '@salesforce/apex/OpportunityUpdateController.getData'; 
import updateRecords from '@salesforce/apex/OpportunityUpdateController.updateRecords';
import createBillingContact from '@salesforce/apex/OpportunityUpdateController.createBillingContact';

import { getRecord, getFieldValue } from 'lightning/uiRecordApi';

import CONTACT_OBJECT from '@salesforce/schema/Contact'; 
import ACCOUNT_ID from '@salesforce/schema/Contact.AccountId';
import FIRST_NAME from '@salesforce/schema/Contact.FirstName';
import LAST_NAME from '@salesforce/schema/Contact.LastName';
import EMAIL from '@salesforce/schema/Contact.Email';
import MAILING_STREET from '@salesforce/schema/Contact.MailingStreet';
import MAILING_CITY from '@salesforce/schema/Contact.MailingCity';
import MAILING_STATE_CODE from '@salesforce/schema/Contact.MailingStateCode';
import MAILING_COUNTRY_CODE from '@salesforce/schema/Contact.MailingCountryCode';
import MAILING_POSTAL_CODE from '@salesforce/schema/Contact.MailingPostalCode';
import TAX_ID from '@salesforce/schema/Contact.Account.Tax_Identifier__c';
import INVOICE_CC_EMAIL from '@salesforce/schema/Contact.Invoice_CC_Emails__c';
import INVOICE_DELIVERY_METHOD from '@salesforce/schema/Contact.Invoice_Delivery_Method__c';

import { ShowToastEvent } from 'lightning/platformShowToastEvent'; 
 
import { getObjectInfo } from 'lightning/uiObjectInfoApi'; 
import { getPicklistValuesByRecordType } from 'lightning/uiObjectInfoApi';

const FIELDS = [
    ACCOUNT_ID,
    FIRST_NAME,
    LAST_NAME,
    EMAIL,
    MAILING_STREET,
    MAILING_CITY,
    MAILING_STATE_CODE,
    MAILING_COUNTRY_CODE,
    MAILING_POSTAL_CODE,
    INVOICE_CC_EMAIL,
    INVOICE_DELIVERY_METHOD,
    TAX_ID
];

export default class OpportunityUpdateQuickAction extends LightningElement {

    // UI
    isLoading = false; 
    showBanner = true;
    showModal = false;
    isCreateNewContact = false;
    isP5MandatePending = false;
    currentStep = 1;

    showNewContactForm = false;
    hasOpportunityLineItems = false;
    saveType = 'Save & Next';

    // Opportunity
    poNumber;
    lexionUrl;
    stageName;


    // Agency
    agencyId;
    agencyTaxIdentifier;
    agencyPaymentTerms;
    agencyLegalName;
    agencyBillingAddress;

    // Advertiser
    accountId; 
    accountTaxIdentifier;
    accountPaymentTerms;
    accountLegalName;
    accountBillingAddress;
    accountBillingCity;
    accountBillingCountry;

    // Billing Contact
    billingContactId;
    billingAccountId;
    firstName;
    lastName;
    email;
    taxId;
    deliveryMethod;
    street;
    city;
    state;
    country;
    zipCode;
    invoiceDeliveryMethod;
    invoiceCCEmail;
    accountType = 'Account';

    _recordId;
    selectedContactId;
    countryOptions = []; 
    stateOptions = [];
    contactRecordTypeId;

    allStateValues;
    allCountryValues;

    contactDisplayInfo = {
        primaryField: 'Name',
        additionalFields: ['Account.Name']
    };


    // =====================================
    // Getters
    // =====================================

    get currentStepString() {
        return String(this.currentStep);
    }

    get isStep1() {
        return this.currentStep === 1;
    }

    get isStep2() {
        return this.currentStep === 2;
    }

    get isStep3() {
        return this.currentStep === 3;
    }

    get isStep4() {
        return this.currentStep === 4;
    }

    get isFirstStep() {
        return this.currentStep === 1;
    }

    get isLastStep() {
        return this.currentStep === 4;
    }

    get showSuccessBanner() {
        // If stage is P3 and mandate is pending, don't show success banner
        console.log('this.hasOpportunityLineItems:'+this.hasOpportunityLineItems);
        console.log('this.stageName:'+this.stageName);
        console.log('this.isP5MandatePending:'+this.isP5MandatePending);
        if (
            this.stageName?.trim() === 'P3: Proposal/RFP' && 
            this.hasOpportunityLineItems === false
        ) {
            return false;
        }
        console.log('IsP5MandatePending :'+this.isP5MandatePending);
        return this.isP5MandatePending === true;
    }

    get showRequiredFieldBanner() {
        console.log('IsP5MandatePending 1 :'+this.isP5MandatePending);
        return this.isP5MandatePending;
    }

    get accountTypeOptions() {
        return [
            { label: 'Account', value: 'Account' },
            { label: 'Agency', value: 'Agency' }
        ];
    }

    get invoiceDeliveryOptions() {
        return [
            { label: 'Email', value: 'Email' },
            { label: 'Portal', value: 'Portal' }
        ];
    }
 
    get isAccount() {
        return this.accountType === 'Account';
    }

    get showAdvertiserStep() {
        return !!this.accountId;
    }

    get showAgencyStep() {
        return !!this.agencyId;
    }

    get isNextDisabled() {
        switch (this.currentStep) {

            // Billing Contact
            case 1:
                return !(
                    this.firstName?.trim() &&
                    this.lastName?.trim() &&
                    this.email?.trim() &&
                    this.street?.trim() &&
                    this.city?.trim() &&
                    this.country?.trim() &&
                    this.taxId?.trim() &&
                    this.zipCode?.trim()
                );

            // Advertiser
            case 2:
                return !(
                    this.accountLegalName?.trim() &&
                    this.accountBillingCountry?.trim()
                );

            // Agency
            case 3:
                return !(
                    this.agencyLegalName?.trim()
                );

            // Opportunity
            case 4:
                return !(
                    this.poNumber?.trim()
                );

            default:
                return true;
        }
    }
  
    get contactFilter() {
        if (!this.accountId && !this.agencyId) {
            return null;
        }
        const criteria = [];
        if (this.accountId) {
            criteria.push({
                fieldPath: 'AccountId',
                operator: 'eq',
                value: this.accountId
            });
        }

        if (this.agencyId) {
            criteria.push({
                fieldPath: 'AccountId',
                operator: 'eq',
                value: this.agencyId
            });
        }
        return {
            criteria,
            filterLogic: criteria.length === 2 ? '1 OR 2' : '1'
        };
    }

    // =====================================
    // Record Id
    // =====================================

    @api
    set recordId(value) {
        this._recordId = value;

        if (value) {
            this.loadData();
        }
    }

    get recordId() {
        return this._recordId;
    }

    @wire(getObjectInfo, {
        objectApiName: CONTACT_OBJECT
    })
    objectInfoHandler({ data }) {
        if (data) {
            this.contactRecordTypeId = data.defaultRecordTypeId;
        }
    }

    @wire(getPicklistValuesByRecordType, {
        objectApiName: CONTACT_OBJECT,
        recordTypeId: '$contactRecordTypeId'
    })
    picklistHandler({ data, error }) {
        if (data) {
            this.countryOptions =
                data.picklistFieldValues.MailingCountryCode.values.map(
                    item => ({
                        label: item.label,
                        value: item.value
                    })
                );

            this.allStateValues =
                data.picklistFieldValues.MailingStateCode;

            console.log(
                'State Metadata',
                JSON.stringify(this.allStateValues)
            );
        }
        if (error) {
            console.error(error);
        }
    }

    @wire(getRecord, {
        recordId: '$selectedContactId',
        fields: FIELDS
    })
    wiredContact({ error, data }) {
        if (data) {
            this.billingAccountId = getFieldValue(data, ACCOUNT_ID);
            this.firstName = getFieldValue(data, FIRST_NAME);
            this.lastName = getFieldValue(data, LAST_NAME);
            this.email = getFieldValue(data, EMAIL);
            this.taxId = getFieldValue(data, TAX_ID);
            this.street = getFieldValue(data, MAILING_STREET);
            this.city = getFieldValue(data, MAILING_CITY);
            this.country = getFieldValue(data, MAILING_COUNTRY_CODE);
            this.zipCode = getFieldValue(data, MAILING_POSTAL_CODE);
            this.invoiceDeliveryMethod = getFieldValue(data, INVOICE_DELIVERY_METHOD);
            this.invoiceCCEmail = getFieldValue(data, INVOICE_CC_EMAIL);
            this.updateStateOptions(this.country);

            this.state = getFieldValue(data, MAILING_STATE_CODE);
        } else if (error) {
            console.error('Error fetching contact', error);
        }
    }

    handleNewContact() {
        this.showNewContactForm = true;
        this.isCreateNewContact = true;
        this.selectedContactId = null;
    }

    // =====================================
    // Modal
    // =====================================
    async openModal() {

        this.showModal = true;
        this.currentStep = 1;
        this.isLoading = true;

        try {

            await this.loadData();

            if (this.billingContactId) {

                // Existing Billing Contact found
                this.showNewContactForm = false;
                this.isCreateNewContact = false;

            } else {

                // No Billing Contact on Opportunity
                this.showNewContactForm = false;
                this.isCreateNewContact = false;
                this.selectedContactId = null;
            }

        } catch (error) {

            this.showToast(
                'Error',
                this.reduceError(error),
                'error'
            );

        } finally {

            this.isLoading = false;
        }
    }

    closeModal() { 
        this.showModal = false;
        this.currentStep = 1;
        this.loadData();
    }

    // =====================================
    // Navigation
    // =====================================

    handleNext() {
        if (!this.validateCurrentStep()) {
            return;
        }

        let nextStep = this.currentStep + 1;

        // Skip Advertiser
        if (nextStep === 2 && !this.accountId) {
            nextStep++;
        }

        // Skip Agency
        if (nextStep === 3 && !this.agencyId) {
            nextStep++;
        }

        this.currentStep = nextStep;
    }

    handlePrevious() {

        let previousStep = this.currentStep - 1;

        while (
            (previousStep === 3 && !this.agencyId) ||
            (previousStep === 2 && !this.accountId)
        ) {
            previousStep--;
        }

        this.currentStep = previousStep;
    }

    // =====================================
    // Generic Field Change
    // =====================================
    handleFieldChange(event) {

        const fieldName = event.target.name;
        const value =
            event.detail?.value ?? event.target.value;

        this[fieldName] = value;

        switch (fieldName) { 

            case 'country':
                this.state = '';
                this.updateStateOptions(value);
                break;

            case 'accountBillingCountry':
                this.accountBillingState = '';
                this.updateStateOptions(value);
                break;

            default:
                break;
        }
    }

    updateStateOptions(countryCode) { 
        if (!this.allStateValues) {
            return;
        }

        const controllerKey =
            this.allStateValues.controllerValues[countryCode];
        
        console.log('controllerKey:'+controllerKey);

        if (controllerKey === undefined) {
            this.stateOptions = [];
            return;
        }

        this.stateOptions =
            this.allStateValues.values
                .filter(state =>
                    state.validFor.includes(controllerKey)
                )
                .map(state => ({
                    label: state.label,
                    value: state.value
                }));

        console.log(
            'Filtered States:',
            JSON.stringify(this.stateOptions)
        );
    }

    async handleCreateContact() { 
        try {
            console.log('accountId:', this.accountId);
            console.log('agencyId:', this.agencyId);

            const hasMissingFields = !(
                this.firstName?.trim() &&
                this.lastName?.trim() &&
                this.email?.trim() &&
                this.street?.trim() &&
                this.city?.trim() &&
                this.country?.trim() &&
                this.zipCode?.trim()
            );

            if (hasMissingFields) {
                this.showToast(
                    'Error',
                    'Please fill all mandatory fields.',
                    'error'
                );
                return;
            }

            if (
                (this.isAccount && !this.accountId) ||
                (!this.isAccount && !this.agencyId)
            ) {
                this.showToast(
                    'Error',
                    `Please select an ${this.isAccount ? 'Account' : 'Agency'}.`,
                    'error'
                );
                return;
            }

            this.isLoading = true;

            const contactId = await createBillingContact({
                opportunityId: this.recordId,
                contactData: {
                    FirstName: this.firstName.trim(),
                    LastName: this.lastName.trim(),
                    Email: this.email.trim(),
                    AccountId: this.isAccount ? this.accountId : this.agencyId,
                    MailingStreet: this.street?.trim(),
                    MailingStateCode: this.state,
                    MailingCity: this.city?.trim(),
                    MailingCountryCode: this.country,
                    MailingPostalCode: this.zipCode?.trim(),
                    Invoice_CC_Emails__c: this.invoiceCCEmail?.trim(),
                    Invoice_Delivery_Method__c: this.invoiceDeliveryMethod?.trim(),
                }
            });

            this.taxId = this.isAccount
                ? this.accountTaxIdentifier
                : this.agencyTaxIdentifier;

            this.billingContactId = contactId;
            this.billingAccountId = this.isAccount ? this.accountId : this.agencyId;
            this.showNewContactForm = false;
            this.isCreateNewContact = false;

            this.showToast(
                'Success',
                'Billing Contact created successfully.',
                'success'
            );

        } catch (error) {
            this.showToast(
                'Error',
                this.reduceError(error),
                'error'
            );
        } finally {
            this.isLoading = false;
        }
    }
    // =====================================
    // Validation
    // =====================================

    validateCurrentStep() {
        return true;
    }

    validateFields() {

        if (!this.poNumber?.trim()) {

            this.showToast(
                'Validation Error',
                'PO Number is required.',
                'error'
            );

            return false;
        }

        return true;
    }

    // =====================================
    // Load Data
    // =====================================

    async loadData() {

        try {
            this.isLoading = true; 
            const result = await getData({
                opportunityId: this.recordId
            });

            // Opportunity
            this.poNumber =
                result.opportunity?.PO_Number__c;
            this.lexionUrl =
                result.opportunity?.Lexion_Contract_URL__c;
            this.stageName =
                result.opportunity?.StageName;
            this.isP5MandatePending = result.opportunity?.Is_P5_Mandate_Pending__c || false;
            
            this.hasOpportunityLineItems = result.hasOpportunityLineItems;
            console.log('this.hasOpportunityLineItems:'+this.hasOpportunityLineItems);

            // Agency
            if (result.agency) {
                this.agencyId =
                    result.agency.Id;
                this.agencyLegalName =
                    result.agency.Registered_Legal_Name__c;
                this.agencyTaxIdentifier = result.agency.Tax_Identifier__c;
            }

            // Advertiser
            if (result.account) {
                this.accountId =
                    result.account.Id;
                this.accountLegalName =
                    result.account.Registered_Legal_Name__c;
                this.accountBillingCountry =
                    result.account.BillingCountryCode;
                this.accountTaxIdentifier = result.account.Tax_Identifier__c;
            }

            // Billing Contact
            if (result.billingContact) {
                this.billingContactId = result.billingContact.Id;
                this.billingAccountId = result.billingContact.AccountId;
                this.firstName = result.billingContact.FirstName;
                this.lastName = result.billingContact.LastName;
                this.email = result.billingContact.Email;
                this.taxId = result.billingContact.Account?.Tax_Identifier__c;
                this.street = result.billingContact.MailingStreet;
                this.city = result.billingContact.MailingCity;
                this.invoiceDeliveryMethod = result.billingContact.Invoice_Delivery_Method__c;
                this.invoiceCCEmail = result.billingContact.Invoice_CC_Emails__c;
                this.country = result.billingContact.MailingCountryCode;
                this.zipCode = result.billingContact.MailingPostalCode;

                this.updateStateOptions(this.country);

                this.state = result.billingContact.MailingStateCode;
            } else {
                this.billingContactId = null;
                this.firstName = '';
                this.lastName = '';
                this.email = '';
                this.taxId = '';
                this.street = '';
                this.city = '';
                this.state = '';
                this.country = '';
                this.zipCode = '';
                this.invoiceCCEmail = '';
                this.invoiceDeliveryMethod = '';
            }
        } catch (error) {

            this.showToast(
                'Error',
                this.reduceError(error),
                'error'
            );

        } finally {

            this.isLoading = false;
        }
    }

    // =====================================
    // Update
    // =====================================

    async handleSaveAndNext() { 
        try {

            this.isLoading = true;

            let payload = {};

            switch (this.currentStep) {

                case 1:

                    payload = {
                        billingContactData: {
                            Id: this.billingContactId,
                            FirstName: this.firstName,
                            LastName: this.lastName,
                            Email: this.email,
                            MailingStreet: this.street,
                            MailingCity: this.city,
                            MailingStateCode: this.state,
                            MailingCountryCode: this.country,
                            MailingPostalCode: this.zipCode,
                            Invoice_CC_Emails__c: this.invoiceCCEmail,
                            Invoice_Delivery_Method__c: this.invoiceDeliveryMethod
                        },

                        billingAccountData: this.billingAccountId ? {
                            Id: this.billingAccountId,
                            Tax_Identifier__c: this.taxId
                        } : null
                    };

                    break;

                case 2:

                    payload = {
                        accountData: {
                            Id: this.accountId,
                            Registered_Legal_Name__c: this.accountLegalName,
                            BillingCountryCode: this.accountBillingCountry
                        }
                    };

                    break;

                case 3:

                    payload = {
                        agencyData: {
                            Id: this.agencyId,
                            Registered_Legal_Name__c: this.agencyLegalName
                        }
                    };

                    break;

                default:
                    break;
            }

            if (Object.keys(payload).length > 0) {
                await updateRecords(payload);
            }

            // Move to next available step
            let nextStep = this.currentStep + 1;

            while (
                (nextStep === 2 && !this.accountId) ||
                (nextStep === 3 && !this.agencyId)
            ) {
                nextStep++;
            }

            this.currentStep = nextStep;

            this.showToast(
                'Success', 
                'Information saved successfully.',
                'success'
            );

        } catch (error) {

            this.showToast(
                'Error',
                this.reduceError(error),
                'error'
            );

        } finally {

            this.isLoading = false;
        }
    }

    handleMarkSignedWonUpdate() {
        this.stageName = 'P5: Signed/Won';
        this.saveType = 'MarkSignedWon';
        this.handleUpdate();
    } 

    async handleUpdate() {

        if (!this.validateFields()) {
            return;
        }

        try {
            const oppData = {
                Id: this.recordId,
                PO_Number__c: this.poNumber,
                Lexion_Contract_URL__c: this.lexionUrl
            };

            if (this.saveType === 'MarkSignedWon') {
                oppData.StageName = this.stageName;
                this.saveType = '';
            }

            this.isLoading = true;

            await updateRecords({
                oppData
            });
 
            this.showToast(
                'Success',
                'Records updated successfully.',
                'success'
            ); 
 
            this.closeModal();
            // Refresh page 
            window.location.reload();

        } catch (error) { 
            this.showToast(
                'Error',
                this.reduceError(error),
                'error'
            );

        } finally {

            this.isLoading = false;
        }
    }

    // =====================================
    // Utilities
    // =====================================

    showToast(title, message, variant) {

        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    } 

    handleContactSelection(event) {
         this.selectedContactId = event.detail.recordId;
    }

    async handleBillingContactUpdate() {
        try { 
            await updateRecords({
                oppData: {
                    Id: this.recordId,
                    Billing_Contact__c: this.selectedContactId
                }
            });
            this.billingContactId = this.selectedContactId; 
            this.showNewContactForm = false;
            this.isCreateNewContact = false;

            if (this.selectedContactId) {
                this.showToast(
                    'Success',
                    'Billing Contact updated successfully.',
                    'success'
                );
            }
        } catch (error) {
            this.showToast(
                'Error',
                this.reduceError(error),
                'error'
            );
        }
    }

    reduceError(error) {

        if (error?.body?.message) {
            return error.body.message;
        }

        if (
            error?.body?.pageErrors?.length
        ) {
            return error.body.pageErrors[0].message;
        }

        if (error?.body?.fieldErrors) {
            return JSON.stringify(
                error.body.fieldErrors
            );
        }

        return 'An unexpected error occurred.';
    }
}