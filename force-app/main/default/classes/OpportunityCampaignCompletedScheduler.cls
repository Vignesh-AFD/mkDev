global class OpportunityCampaignCompletedScheduler implements Schedulable {
    global void execute(SchedulableContext sc) {
        OpportunityCampaignCompletedBatch batch = new OpportunityCampaignCompletedBatch();
        Database.executeBatch(batch, 200); // Batch size of 200
    }
}