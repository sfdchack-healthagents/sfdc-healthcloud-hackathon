public without sharing class Agent_SFX_DynamicAgentController { 

    @AuraEnabled(cacheable=true)
    public static String getOrgBaseUrl() {
        return URL.getOrgDomainUrl().toExternalForm();
    }


    @AuraEnabled(cacheable=true)
    public static String getObjectApiName(Id recordId) {
        String keyPrefix = ((String)recordId).substring(0, 3);
        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
        
        // First, try to get by key prefix from a sorted list to ensure consistent order
        List<String> objectNames = new List<String>(globalDescribe.keySet());
        objectNames.sort();
        
        List<Schema.SObjectType> matches = new List<Schema.SObjectType>();
        for (String name : objectNames) {
            Schema.SObjectType sObjType = globalDescribe.get(name);
            Schema.DescribeSObjectResult describe = sObjType.getDescribe();
            if (describe.getKeyPrefix() == keyPrefix) {
                matches.add(sObjType);
            }
        }
        
        // If we have matches, return the first one (should be more consistent now)
        // But prefer exact matches for common objects
        String taskPrefix = Task.SObjectType.getDescribe().getKeyPrefix();
        if (keyPrefix == taskPrefix) {
            return 'Task';
        }
        
        if (!matches.isEmpty()) {
            return matches[0].getDescribe().getName();
        }
        
        throw new AuraHandledException('Unable to determine object type for ID: ' + recordId);
    }

    @AuraEnabled(cacheable=true)
    public static String getObjectLabel(String objectApiName) {
        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
        Schema.SObjectType sObjType = globalDescribe.get(objectApiName);
        
        if (sObjType != null) {
            Schema.DescribeSObjectResult describe = sObjType.getDescribe();
            return describe.getLabel();
        }
        
        return objectApiName;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getFieldConfigurationWithIcon(String objectApiName, String componentName) {
       
        List<Salesforce_General_Setting__c> settings = [
            SELECT Query_Fields__c, SF2_Icon_URL__c 
            FROM Salesforce_General_Setting__c 
            WHERE Object__c = :objectApiName AND SF2_Component_Name__c = :componentName
            LIMIT 1
        ];

        Map<String, Object> result = new Map<String, Object>();
        
        if (settings.isEmpty()) {
            System.debug('No Salesforce_General_Setting found for Object: ' + objectApiName + ', Component: ' + componentName);
            result.put('fields', '');
            result.put('iconUrl', '');
            return result;
        }

        Salesforce_General_Setting__c setting = settings[0];
        result.put('fields', setting.Query_Fields__c);
        result.put('iconUrl', setting.SF2_Icon_URL__c);
        return result;
    }



    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getRecordData(Id recordId, String fieldApiNames) {
        String objectApiName = getObjectApiName(recordId);
        String query = 'SELECT Id,' + fieldApiNames + ' FROM ' + objectApiName + ' WHERE Id = \'' + String.escapeSingleQuotes(recordId) + '\' LIMIT 1';
        System.debug('SOQL Query: ' + query);
        SObject record = Database.query(query);
        System.debug('Raw SObject: ' + record);
        Map<String, Object> result = new Map<String, Object>();
        for (String field : fieldApiNames.split(',')) {
            field = field.trim();
            System.debug('Processing field: ' + field);
            if (field.contains('.')) {
                List<String> parts = field.split('\\.');
                SObject relObj = record;
                for (Integer i = 0; i < parts.size() - 1; i++) {
                    if (relObj != null) {
                        // Use getSObject for relationship traversal
                        relObj = relObj.getSObject(parts[i]);
                        System.debug('Traversed to relationship: ' + parts[i] + ' | Value: ' + relObj);
                    } else {
                        System.debug('Null relationship encountered at: ' + parts[i]);
                        break;
                    }
                }
                Object relValue = (relObj != null) ? relObj.get(parts[parts.size() - 1]) : null;
                System.debug('Relationship field value for ' + field + ': ' + relValue);
                result.put(field, relValue);
            } else {
                Object value = record.get(field);
                System.debug('Direct field value for ' + field + ': ' + value);
                result.put(field, value);
            }
        }
        result.put('Id', record.Id);
        System.debug('Final result map: ' + result);
        return result;
    }
    
    // @AuraEnabled(cacheable=true)
    // public static List<Map<String, Object>> getRecordAllData(Id recordId, String fieldJson) {
    //     // Parse the input JSON
    //     Map<String, Object> fieldMap = (Map<String, Object>) JSON.deserializeUntyped(fieldJson);

    //     Set<String> fieldApiNamesSet = new Set<String>();
    //     Map<String, Map<String, Object>> fieldDetailsMap = new Map<String, Map<String, Object>>();

    //     for (String key : fieldMap.keySet()) {
    //         Object fieldEntry = fieldMap.get(key);
    //         Map<String, Object> fieldDetails;

    //         if (fieldEntry instanceof Map<String, Object>) {
    //             fieldDetails = (Map<String, Object>) fieldEntry;
    //         } else {
    //             fieldDetails = new Map<String, Object>();
    //         }

    //         String apiName = (String) fieldDetails.get('fieldAPIName');
    //         if (String.isBlank(apiName)) {
    //             apiName = key;
    //         }

    //         fieldDetails.put('fieldAPIName', apiName);
    //         fieldDetails.put('fieldLabel', fieldDetails.containsKey('fieldLabel') ? fieldDetails.get('fieldLabel') : key);
    //         fieldDetails.put('isShow', fieldDetails.containsKey('isShow') ? fieldDetails.get('isShow') : true);
            

    //         fieldApiNamesSet.add(apiName);
    //         fieldDetailsMap.put(key, fieldDetails);
    //     }

    //     String objectApiName = getObjectApiName(recordId);
    //     String query = 'SELECT Id, ' + String.join(new List<String>(fieldApiNamesSet), ',') +
    //                 ' FROM ' + objectApiName + ' WHERE Id = :recordId LIMIT 1';
    //     System.debug('SOQL Query: ' + query);

    //     SObject record = Database.query(query);

    //     List<Map<String, Object>> resultList = new List<Map<String, Object>>();

    //     for (String key : fieldDetailsMap.keySet()) {
    //         Map<String, Object> fieldDetails = fieldDetailsMap.get(key);
    //         String apiName = (String) fieldDetails.get('fieldAPIName');
    //         Object value;

    //         if (apiName.contains('.')) {
    //             List<String> parts = apiName.split('\\.');
    //             SObject relObj = record;
    //             for (Integer i = 0; i < parts.size() - 1; i++) {
    //                 if (relObj != null) {
    //                     relObj = relObj.getSObject(parts[i]);
    //                 } else {
    //                     break;
    //                 }
    //             }
    //             value = (relObj != null) ? relObj.get(parts[parts.size() - 1]) : null;
    //         } else {
    //             value = record.get(apiName);
    //         }

    //         Map<String, Object> innerMap = new Map<String, Object>();
    //         innerMap.put('fieldLabel', fieldDetails.get('fieldLabel'));
    //         innerMap.put('fieldValue', value);
    //         innerMap.put('isShow', fieldDetails.get('isShow'));

    //         Map<String, Object> outerMap = new Map<String, Object>();
    //         outerMap.put(key, innerMap);

    //         resultList.add(outerMap);
    //     }

    //     return resultList;
    // }

    @AuraEnabled(cacheable=true)
    public static List<Object> getRecordAllData(Id recordId, String fieldJson) {
        Map<String, Object> fieldMap = (Map<String, Object>) JSON.deserializeUntyped(fieldJson);

        Set<String> fieldApiNamesSet = new Set<String>();
        Map<String, Map<String, Object>> fieldDetailsMap = new Map<String, Map<String, Object>>();

        for (String key : fieldMap.keySet()) {
            Object fieldEntry = fieldMap.get(key);
            Map<String, Object> fieldDetails = (fieldEntry instanceof Map<String, Object>) ? (Map<String, Object>) fieldEntry : new Map<String, Object>();

            String apiName = (String) fieldDetails.get('fieldAPIName');
            if (String.isBlank(apiName)) {
                apiName = key;
            }

            fieldDetails.put('fieldAPIName', apiName);
            fieldDetails.put('fieldLabel', fieldDetails.containsKey('fieldLabel') ? fieldDetails.get('fieldLabel') : key);
            fieldDetails.put('isShow', fieldDetails.containsKey('isShow') ? fieldDetails.get('isShow') : true);
            fieldDetails.put('getParentID', fieldDetails.containsKey('getParentID') ? fieldDetails.get('getParentID') : false);

            fieldApiNamesSet.add(apiName);
            fieldDetailsMap.put(key, fieldDetails);
        }

        String objectApiName = getObjectApiName(recordId);
        String query = 'SELECT Id, ' + String.join(new List<String>(fieldApiNamesSet), ',') +
                    ' FROM ' + objectApiName + ' WHERE Id = :recordId LIMIT 1';
        System.debug('SOQL Query: ' + query);

        SObject record = Database.query(query);

        List<Map<String, Object>> resultList = new List<Map<String, Object>>();

        for (String key : fieldDetailsMap.keySet()) {
            Map<String, Object> fieldDetails = fieldDetailsMap.get(key);
            String apiName = (String) fieldDetails.get('fieldAPIName');
            Boolean getParentID = (Boolean) fieldDetails.get('getParentID');
            Object value;
            String parentId = null;

            if (apiName.contains('.')) {
                List<String> parts = apiName.split('\\.');
                SObject relObj = record;
                for (Integer i = 0; i < parts.size() - 1; i++) {
                    if (relObj != null) {
                        relObj = relObj.getSObject(parts[i]);
                    } else {
                        break;
                    }
                }
                value = (relObj != null) ? relObj.get(parts[parts.size() - 1]) : null;
                if (getParentID && relObj != null && relObj.get('Id') != null) {
                    parentId = (String) relObj.get('Id');
                }
            } else {
                value = record.get(apiName);
            }

            Map<String, Object> innerMap = new Map<String, Object>();
            innerMap.put('fieldLabel', fieldDetails.get('fieldLabel'));
            innerMap.put('fieldValue', value);
            innerMap.put('isShow', fieldDetails.get('isShow'));
            if (getParentID && parentId != null) {
                innerMap.put('parentID', parentId);
            }

            resultList.add(innerMap);
        }

        return resultList;
    }




    // @AuraEnabled
    // public static Id createDynamicRecord(String objectApiName, Map<String, Object> fieldValues) {
    //     SObject newRecord = Schema.getGlobalDescribe().get(objectApiName).newSObject();

    //     for (String fieldName : fieldValues.keySet()) {
    //         newRecord.put(fieldName, fieldValues.get(fieldName));
    //     }

    //     insert newRecord;
    //     return newRecord.Id;
    // }

}