import { LightningElement, track } from 'lwc';

export default class CpmCalculator extends LightningElement {
    @track totalCost = '';
    @track cpm = '';
    @track impressions = '';
    @track showError = false;

    // Handle Total Cost input change
    handleTotalCostChange(event) {
        this.totalCost = event.target.value;
        this.hideError();
    }

    // Handle CPM input change
    handleCpmChange(event) {
        this.cpm = event.target.value;
        this.hideError();
    }

    // Handle Impressions input change
    handleImpressionsChange(event) {
        this.impressions = event.target.value;
        this.hideError();
    }

    // Calculate the missing value
    handleCalculate() {
        const filledFields = this.getFilledFieldCount();

        if (filledFields !== 2) {
            this.showError = true;
            return;
        }

        this.hideError();

        // Calculate based on which fields are filled
        if (this.totalCost && this.cpm) {
            // Calculate Impressions: Impressions = (Total Cost / CPM) * 1000
            this.impressions = Math.round((parseFloat(this.totalCost) / parseFloat(this.cpm)) * 1000).toString();
        } else if (this.totalCost && this.impressions) {
            // Calculate CPM: CPM = (Total Cost / Impressions) * 1000
            this.cpm = (parseFloat(this.totalCost) / parseFloat(this.impressions) * 1000).toFixed(2);
        } else if (this.cpm && this.impressions) {
            // Calculate Total Cost: Total Cost = (CPM * Impressions) / 1000
            this.totalCost = (parseFloat(this.cpm) * parseFloat(this.impressions) / 1000).toFixed(2);
        }
    }

    // Reset all fields
    handleReset() {
        this.totalCost = '';
        this.cpm = '';
        this.impressions = '';
        this.hideError();
    }

    // Helper method to count filled fields
    getFilledFieldCount() {
        let count = 0;
        if (this.totalCost) count++;
        if (this.cpm) count++;
        if (this.impressions) count++;
        return count;
    }

    // Hide error message
    hideError() {
        this.showError = false;
    }
}