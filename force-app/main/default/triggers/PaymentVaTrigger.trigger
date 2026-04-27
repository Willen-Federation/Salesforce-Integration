trigger PaymentVaTrigger on Payment__c (after insert) {
    PaymentVaTriggerHandler.handleAfterInsert(Trigger.new);
}
