public with sharing class SyncToOtherOrg {
    @future(callout=true)
    public static void sendRecords(String objectName, String jsonRecords) {
        try {

     String endpoint = 'callout:kirtiNamedCreds/services/apexrest/RecordSync';
            
     System.debug('Serialized JSON in sendRecords: ' + jsonRecords);

        // Deserialize JSON as a list of maps
        List<Object> rawRecords = (List<Object>) JSON.deserializeUntyped(jsonRecords);

        // Convert raw records to list of maps
        List<Map<String, Object>> records = new List<Map<String, Object>>();
        for (Object obj : rawRecords) {
            records.add((Map<String, Object>) obj);
        }

        // Ensure External_ID__c exists in each record
        for (Map<String, Object> record : records) {
            if (!record.containsKey('External_ID__c') || String.isBlank(String.valueOf(record.get('External_ID__c')))) {
                   record.put('External_ID__c', String.valueOf(record.get('Id')));
                System.debug(record);

            }
        }

        // Prepare the request body
        Map<String, Object> requestBody = new Map<String, Object>();
        requestBody.put('objectName', objectName);
        requestBody.put('jsonRecords', JSON.serialize(records));
            

        // Set the body as JSON
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(requestBody));

        // Execute Callout
        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
            System.debug('Success: ' + res.getBody());
        } else {
            System.debug('Error: Status Code - ' + res.getStatusCode() + ', Response - ' + res.getBody());
        }
    } catch (Exception e) {
        System.debug('Exception during callout: ' + e.getMessage());
    }
    }

    
@future(callout=true)
public static void sendUpdatedRecords(String objectName, String jsonRecords) {
    try {
        System.debug('Incoming JSON: ' + jsonRecords.substring(0, Math.min(1000, jsonRecords.length())));

        // Deserialize JSON into a List of Objects
        List<Object> rawParsed = (List<Object>) JSON.deserializeUntyped(jsonRecords);
        System.debug('Deserialized Object: ' + rawParsed);

        // Prepare a list to hold the final records
        List<Map<String, Object>> records = new List<Map<String, Object>>();

        // Ensure the deserialized data is a List of Objects and iterate
        if (rawParsed != null && !rawParsed.isEmpty()) {
            System.debug('RawParsed is a List<Object>');

            // Iterate over each item in the list
            for (Object obj : rawParsed) {
                // Ensure the object is a Map<String, Object>
                if (obj instanceof Map<String, Object>) {
                    Map<String, Object> recordMap = (Map<String, Object>) obj; // Cast to Map<String, Object>

                    if (!recordMap.isEmpty()) {
                        records.add(recordMap);
                    }
                } else {
                    System.debug('Skipping invalid object (not a Map<String, Object>): ' + obj);
                }
            }
        } else {
            System.debug('Error: Deserialized JSON is not a List or is empty!');
            return;
        }

        if (!records.isEmpty()) {
            System.debug('Converted Records: ' + records);
            
            // Ensure 'External_ID__c' is set if missing
            for (Map<String, Object> record : records) {
                if (!record.containsKey('External_ID__c') || String.isBlank(String.valueOf(record.get('External_ID__c')))) {
                    record.put('External_ID__c', String.valueOf(record.get('Id')));
                }
            }

            // Prepare the payload for the request
            Map<String, Object> payload = new Map<String, Object>{
                'objectName' => objectName,
                'jsonRecords' => JSON.serialize(records)  // Serialize records as a string
            };

            // Log the final data being sent
            System.debug('Data to update in target org: ' + JSON.serialize(payload));

            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:kirtiNamedCreds/services/apexrest/RecordSyncUpdate');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setBody(JSON.serialize(payload));  // Send the serialized JSON as the body

            Http http = new Http();
            HttpResponse res = http.send(req);
            
            if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
                System.debug('Success: ' + res.getBody());
            } else {
                System.debug('Error: Status Code - ' + res.getStatusCode() + ', Response - ' + res.getBody());
            }
        } else {
            System.debug('No valid records to send.');
        }

    } catch (Exception e) {
        // Handle and log exceptions
        System.debug('Exception: ' + e.getMessage());
    }
}

 @future(callout=true)
public static void sendDeletedRecords(String objectName, String jsonRecords) {
    try {
        System.debug('Deleting records: ' + jsonRecords);

        // Deserialize JSON into a List of Maps
        List<Object> rawParsed = (List<Object>) JSON.deserializeUntyped(jsonRecords);
         System.debug('Deserialized Object: ' + rawParsed);
        
        List<String> idsToDelete = new List<String>();

        // Process each record in the deserialized list
        for (Object obj : rawParsed) {
            if (obj instanceof Map<String, Object>) {
                Map<String, Object> recordMap = (Map<String, Object>) obj;

                // Check for External_ID__c and fallback to Id if missing
                String externalId = null;
                if (recordMap.containsKey('External_ID__c') && !String.isBlank(String.valueOf(recordMap.get('External_ID__c')))) {
                    externalId = String.valueOf(recordMap.get('External_ID__c'));
                } else if (recordMap.containsKey('Id')) {
                    // Fallback to record Id
                    externalId = String.valueOf(recordMap.get('Id'));
                    System.debug('Fallback to Id as External_ID__c was missing: ' + externalId);
                } else {
                    System.debug('No valid External_ID__c or Id found for record: ' + recordMap);
                }

                // Add to the deletion list if a valid identifier is found
                if (!String.isBlank(externalId)) {
                    idsToDelete.add(externalId);
                }
            } else {
                System.debug('Skipping invalid object (not a Map<String, Object>): ' + obj);
            }
        }

        if (!idsToDelete.isEmpty()) {
            String serializedIds = JSON.serialize(idsToDelete);
            System.debug('Serialized IDs for deletion: ' + serializedIds);

            Map<String, Object> payload = new Map<String, Object>{
                'objectName' => objectName,
                'idsToDelete' => serializedIds // Serialize as a JSON array
            };

            String requestBody = JSON.serialize(payload);
            System.debug('Serialized Request Body: ' + requestBody);

            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:kirtiNamedCreds/services/apexrest/RecordSyncDelete');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setBody(requestBody);

            Http http = new Http();
            HttpResponse res = http.send(req);
            
            if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
                System.debug('Success: ' + res.getBody());
            } else {
                System.debug('Delete Error: Status Code - ' + res.getStatusCode() + ', Response - ' + res.getBody());
            }
        } else {
            System.debug('No valid External_ID__c or fallback Id found for deletion.');
        }
    } catch (Exception e) {
        System.debug('Exception during deletion: ' + e.getMessage());
    }
}
    
@future(callout=true)
public static void sendUndeletedRecords(String objectName, String jsonRecords) {
    try {
        System.debug('Undeleting records: ' + jsonRecords);

        List<Object> rawParsed = (List<Object>) JSON.deserializeUntyped(jsonRecords);
        System.debug('Deserialized Object: ' + rawParsed);
        
        List<String> idsToUndelete = new List<String>();

        // Process each record in the deserialized list
        for (Object obj : rawParsed) {
            if (obj instanceof Map<String, Object>) {
                Map<String, Object> recordMap = (Map<String, Object>) obj;

                // Check for External_ID__c and fallback to Id if missing
                String externalId = null;
                if (recordMap.containsKey('External_ID__c') && !String.isBlank(String.valueOf(recordMap.get('External_ID__c')))) {
                    externalId = String.valueOf(recordMap.get('External_ID__c'));
                } else if (recordMap.containsKey('Id')) {
                    // Fallback to record Id
                    externalId = String.valueOf(recordMap.get('Id'));
                    System.debug('Fallback to Id as External_ID__c was missing: ' + externalId);
                } else {
                    System.debug('No valid External_ID__c or Id found for record: ' + recordMap);
                }

                // Add to the undelete list if a valid identifier is found
                if (!String.isBlank(externalId)) {
                    idsToUndelete.add(externalId);
                }
            } else {
                System.debug('Skipping invalid object (not a Map<String, Object>): ' + obj);
            }
        }

        if (!idsToUndelete.isEmpty()) {
            // Serialize the list of IDs
            String serializedIds = JSON.serialize(idsToUndelete);
            System.debug('Serialized IDs for undelete: ' + serializedIds);

            // Prepare the payload
            Map<String, Object> payload = new Map<String, Object> {
                'objectName' => objectName,
                'idsToUndelete' => serializedIds // Serialize as a JSON array
            };
                
            String requestBody = JSON.serialize(payload);
            System.debug('Serialized Request Body: ' + requestBody);

            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:kirtiNamedCreds/services/apexrest/RecordSyncUndelete');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setBody(requestBody);

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
                System.debug('Success: ' + res.getBody());
            } else {
                System.debug('Undelete Error: Status Code - ' + res.getStatusCode() + ', Response - ' + res.getBody());
            }
        } else {
            System.debug('No valid External_ID__c or fallback Id found for undelete.');
        }
    } catch (Exception e) {
        System.debug('Exception during undelete: ' + e.getMessage());
    }
}

}