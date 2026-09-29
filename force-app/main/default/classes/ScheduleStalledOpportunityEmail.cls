public class ScheduleStalledOpportunityEmail implements Schedulable {
    public void execute(SchedulableContext sc) {
        SendStalledOpportunityEmailBatch batch = new SendStalledOpportunityEmailBatch();
        Database.executeBatch(batch, 100);
    }
}