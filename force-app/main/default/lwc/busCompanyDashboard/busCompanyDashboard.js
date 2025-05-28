import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getBusesWithPassengers from '@salesforce/apex/BusCompanyController.getBusesWithPassengers';

// Bus Company fields
import COMPANY_NAME_FIELD from '@salesforce/schema/Bus_Company__c.Name';

const fields = [COMPANY_NAME_FIELD];

export default class BusCompanyDashboard extends LightningElement {
    @api recordId;
    @track buses = [];
    @track error;
    @track isLoading = true;

    // Wire to get Bus Company record
    @wire(getRecord, { recordId: '$recordId', fields })
    companyRecord;

    // Wire to get buses with passengers
    @wire(getBusesWithPassengers, { companyId: '$recordId' })
    wiredBuses({ error, data }) {
        this.isLoading = false;
        if (data) {
            console.log(JSON.stringify(data, null, 2)); // Debugging output
            this.buses = this.processBusData(data);
            this.error = undefined;
        } else if (error) {
            this.error = 'Error loading buses: ' + error.body.message;
            this.buses = [];
        }
    }

    get companyData() {

        console.log('Company Record:', JSON.stringify(this.companyRecord, null, 2)); // Debugging output
        return this.companyRecord.data;
    }

    get hasBuses() {
        return this.buses && this.buses.length > 0;
    }

    processBusData(busData) {
        return busData.map(bus => {
            const passengerCount = bus.Passengers__r ? bus.Passengers__r.length : 0;
            const occupancyPercentage = Math.round((passengerCount / 20) * 100);

            return {
                ...bus,
                passengerCount,
                occupancyPercentage,
                hasPassengers: passengerCount > 0,
                showPassengers: false,
                passengerListLabel: `View Passengers (${passengerCount})`,
                passengerListIcon: 'utility:chevronright',
                statusVariant: this.getStatusVariant(bus.Bus_Status__c),
                progressStyle: `width: ${Math.min(occupancyPercentage, 100)}%`
            };
        });
    }

    getStatusVariant(status) {
        switch (status) {
            case 'Available':
                return 'success';
            case 'Limited Seats':
                return 'warning';
            case 'Full':
                return 'error';
            default:
                return 'base';
        }
    }

    togglePassengerList(event) {
        const busId = event.currentTarget.dataset.busId;
        this.buses = this.buses.map(bus => {
            if (bus.Id === busId) {
                const showPassengers = !bus.showPassengers;
                return {
                    ...bus,
                    showPassengers,
                    passengerListLabel: showPassengers
                        ? `Hide Passengers (${bus.passengerCount})`
                        : `View Passengers (${bus.passengerCount})`,
                    passengerListIcon: showPassengers
                        ? 'utility:chevrondown'
                        : 'utility:chevronright'
                };
            }
            return bus;
        });
    }

    refreshData() {
        this.isLoading = true;

        // Refresh the wired method
        return getBusesWithPassengers({ companyId: this.recordId })
            .then(data => {
                this.buses = this.processBusData(data);
                this.error = undefined;
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Bus data refreshed successfully',
                        variant: 'success'
                    })
                );
            })
            .catch(error => {
                this.error = 'Error refreshing data: ' + error.body.message;
                this.buses = [];
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: 'Failed to refresh bus data',
                        variant: 'error'
                    })
                );
            })
            .finally(() => {
                this.isLoading = false;
            });
    }
}