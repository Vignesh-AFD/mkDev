global class RetryBatchScheduler implements Schedulable {

    // This runs when Salesforce executes the scheduled job (from UI)
   global void execute(SchedulableContext sc) {
        System.debug('Bootstrap Scheduler Triggered');

        // Run the main batch job immediately
        RetryBatchonOli batch = new RetryBatchonOli();
        Database.executeBatch(batch, 50);
    }
}