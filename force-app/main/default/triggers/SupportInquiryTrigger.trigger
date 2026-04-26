trigger SupportInquiryTrigger on SupportInquiry__c (after insert) {
    for (SupportInquiry__c inq : Trigger.new) {
        if (inq.NotifyEmail__c) {
            EmailNotificationService.sendInquiryAutoReply(inq.Id);
        }
        if (inq.NotifySlack__c) {
            SlackIntegrationService.notifySupportInquiry(inq.Id);
        }
    }
}
