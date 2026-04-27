/**
 * 定期支払いスケジューラーの登録・解除・状態確認を管理するコントローラー。
 * 管理者が Setup から Anonymous Apex を実行せずに UI から操作できる。
 */
public with sharing class PortalSchedulerController {

    private static final String JOB_NAME  = '定期支払い生成';
    private static final String CRON_EXPR = '0 0 1 * * ?'; // 毎日 01:00

    // ----------------------------------------------------------------
    // スケジューラー状態確認
    // ----------------------------------------------------------------

    @AuraEnabled(cacheable=false)
    public static Map<String, Object> getSchedulerStatus() {
        List<CronTrigger> jobs = [
            SELECT Id, CronJobDetail.Name, State, NextFireTime, PreviousFireTime
            FROM CronTrigger
            WHERE CronJobDetail.Name = :JOB_NAME
            LIMIT 1
        ];

        if (jobs.isEmpty()) {
            return new Map<String, Object>{
                'isScheduled'    => false,
                'state'          => null,
                'nextFireTime'   => null,
                'previousFireTime' => null
            };
        }

        CronTrigger job = jobs[0];
        return new Map<String, Object>{
            'isScheduled'      => true,
            'jobId'            => (String) job.Id,
            'state'            => job.State,
            'nextFireTime'     => job.NextFireTime != null ? String.valueOf(job.NextFireTime) : null,
            'previousFireTime' => job.PreviousFireTime != null ? String.valueOf(job.PreviousFireTime) : null,
            'cronExpression'   => CRON_EXPR,
            'jobName'          => JOB_NAME
        };
    }

    // ----------------------------------------------------------------
    // 有効化 / 無効化
    // ----------------------------------------------------------------

    @AuraEnabled
    public static void enableScheduler() {
        abortExistingJobs();
        System.schedule(JOB_NAME, CRON_EXPR, new RecurringPaymentScheduler());
    }

    @AuraEnabled
    public static void disableScheduler() {
        abortExistingJobs();
    }

    // ----------------------------------------------------------------
    // Private
    // ----------------------------------------------------------------

    private static void abortExistingJobs() {
        List<CronTrigger> existing = [
            SELECT Id FROM CronTrigger WHERE CronJobDetail.Name = :JOB_NAME
        ];
        for (CronTrigger ct : existing) {
            System.abortJob(ct.Id);
        }
    }
}
