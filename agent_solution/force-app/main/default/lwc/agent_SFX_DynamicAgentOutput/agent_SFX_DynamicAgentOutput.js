import { LightningElement, api, wire } from 'lwc';
import getObjectApiName from '@salesforce/apex/Agent_SFX_DynamicAgentController.getObjectApiName';
import getObjectLabel from '@salesforce/apex/Agent_SFX_DynamicAgentController.getObjectLabel';
import getFieldConfigurationWithIcon from '@salesforce/apex/Agent_SFX_DynamicAgentController.getFieldConfigurationWithIcon';
import getRecordData from '@salesforce/apex/Agent_SFX_DynamicAgentController.getRecordAllData';
import getOrgBaseUrl from '@salesforce/apex/Agent_SFX_DynamicAgentController.getOrgBaseUrl';
import { NavigationMixin } from 'lightning/navigation';

export default class Agent_SFX_DynamicAgentOutput extends NavigationMixin(LightningElement) {
    @api recordId;
    objectApiName;
    _objectLabel = '';
    fieldApiNames = [];
    iconUrl;
    recordData;
    baseURL = '';
    error;
    @api componentName = 'AgentDynamicInput';

    @api
    get recId() {
        return this._recId;
    }
    set recId(recId) {
        this._recId = recId;
    }

    @api
    get value() {
        return this._value;
    }

    set value(value) {
        this._value = value;
    }



    get fetchrecordID() {
        console.log("Record ID : From Dynamic Agent ::" + this.value);
        if (this.recordId) {
            return this.recordId;
        } else if (this.recId) {
            return this.recId
        } else {
            return this.value;
        }
    }

    @wire(getOrgBaseUrl)
    fetchOrgBaseURL({ error, data }) {
        if (data) {
            this.baseURL = data;
            console.log("baseURL ::: " + this.baseURL);
        } else {
            this.error = error?.body?.message || error;
        }
    }

    @wire(getObjectApiName, { recordId: '$fetchrecordID' })
    wiredObjectApiName({ error, data }) {
        if (data) {
            this.objectApiName = data;
            this.fetchObjectLabel();
            this.fetchFieldConfiguration();
        } else {
            this.error = error?.body?.message || error;
        }
    }

    fetchObjectLabel() {
        getObjectLabel({ objectApiName: this.objectApiName })
            .then(label => {
                this._objectLabel = label;
                console.log("Object Label : From Dynamic Agent ::" + this._objectLabel);
            })
            .catch(error => {
                this.error = error?.body?.message || error;
                console.log("Error fetching object label ::" + this.error);
            });
    }

    fetchFieldConfiguration() {
        getFieldConfigurationWithIcon({ objectApiName: this.objectApiName, componentName: this.componentName })
            .then(config => {
                // Parse comma-separated field names and trim whitespace
                this.fieldApiNames = config.fields.split(',').map(field => field.trim());

                this.iconUrl = config.iconUrl;
                console.log("Record ID : From Dynamic Agent getFieldConfigurationWithIcon ::" + JSON.stringify(this.fetchrecordID));
                console.log("getFieldConfigurationWithIcon : From Dynamic Agent ::" + JSON.stringify(this.fieldApiNames));
                this.fetchRecordData();
            })
            .catch(error => {
                this.error = error?.body?.message || error;
            });
    }

    fetchRecordData() {
        getRecordData({ recordId: this.fetchrecordID, fieldJson: this.fieldApiNames })
            .then(data => {
                const processedData = data.map(item => {


                    const clone = { ...item }; // shallow copy
                    if (clone.parentID) {
                        clone.parentURL = this.baseURL + '/' + item.parentID;
                    }
                    return clone;

                });

                this.recordData = processedData;

                console.log("Record Data : From Dynamic Agent fetchRecordData ::" + JSON.stringify(data));
                console.log("Field API Names : From Dynamic Agent ::" + this.recordData);
            })
            .catch(error => {
                this.error = error?.body?.message || error;
                console.log("getRecordData this.fieldApiNames ::" + this.fieldApiNames);
                console.log("getRecordData this.error ::" + this.error);
            });
    }

    handeOnRecordClick() {

        let url = this.baseURL + '/' + this.fetchrecordID;
        console.log("url ::" + url);
        window.open(url, '_blank').focus();

    }

    get displayFields() {
        if (!this.recordData || !Array.isArray(this.recordData)) return [];
        
        // Filter to show only fields marked with isShow = true
        return this.recordData.filter(field => field.isShow === true);
    }

    get objectLabel() {
        return this._objectLabel;
    }
}