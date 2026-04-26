@isTest
private class ActivityControllerTest {

    @TestSetup
    static void setup() {
        Member__c m = new Member__c(
            LastName__c = '活動', FirstName__c = 'テスト',
            Email__c = 'activity@example.com',
            MemberStatus__c = '正会員', MemberType__c = '個人会員'
        );
        insert m;

        Activity__c act = new Activity__c(
            Member__c        = m.Id,
            ActivityTitle__c = 'テスト活動',
            ActivityType__c  = 'その他',
            ActivityDate__c  = Date.today(),
            ActivityStatus__c = '登録済み',
            Hours__c         = 2.0
        );
        insert act;
    }

    @isTest
    static void testCreateActivity() {
        Member__c m = [SELECT Id FROM Member__c LIMIT 1];
        Map<String, Object> data = new Map<String, Object>{
            'memberId'     => (Object)m.Id,
            'title'        => '新しい活動',
            'activityType' => 'セミナー参加',
            'activityDate' => String.valueOf(Date.today()),
            'location'     => '東京都',
            'hours'        => 3,
            'description'  => '詳細説明'
        };
        Test.startTest();
        String actName = ActivityController.createActivity(data);
        Test.stopTest();
        System.assertNotEquals(null, actName);
    }

    @isTest
    static void testCreateActivityNoHours() {
        Member__c m = [SELECT Id FROM Member__c LIMIT 1];
        Map<String, Object> data = new Map<String, Object>{
            'memberId'     => (Object)m.Id,
            'title'        => '時間なし活動',
            'activityType' => '会議出席',
            'activityDate' => String.valueOf(Date.today()),
            'location'     => null,
            'hours'        => null,
            'description'  => null
        };
        Test.startTest();
        String actName = ActivityController.createActivity(data);
        Test.stopTest();
        System.assertNotEquals(null, actName);
    }

    @isTest
    static void testGetActivitiesByMember() {
        Member__c m = [SELECT Id FROM Member__c LIMIT 1];
        Test.startTest();
        List<Activity__c> results = ActivityController.getActivitiesByMember(m.Id);
        Test.stopTest();
        System.assertEquals(1, results.size());
    }
}
