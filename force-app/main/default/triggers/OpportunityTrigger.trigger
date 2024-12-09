trigger OpportunityTrigger on Opportunity (after insert, after update, after delete,  after undelete) {
     
    String objectName = 'Opportunity';
    String recordList = JSON.serialize(Trigger.new);
    
    if (Trigger.isInsert || Trigger.isUpdate) 
    {
        recordList = JSON.serialize(Trigger.new);
        if (Trigger.isUpdate)
        {
            SyncToOtherOrg.sendUpdatedRecords(objectName, recordList);
        } else 
        {
            SyncToOtherOrg.sendRecords(objectName, recordList);
        }
    } else if (Trigger.isDelete) {
        recordList = JSON.serialize(Trigger.old);
        SyncToOtherOrg.sendDeletedRecords(objectName, recordList);
    }
     else if (Trigger.isUndelete) {
        recordList = JSON.serialize(Trigger.new);
        SyncToOtherOrg.sendUndeletedRecords(objectName, recordList);
    }
   
}