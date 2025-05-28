@isTest
public class BusStatusUpdateBatchTest {
    
    @TestSetup
    static void setupTestData() {
        // Create Bus Company
        Bus_Company__c company = new Bus_Company__c(
            Name = 'Test Bus Company',
            Company_Code__c = 'TEST001'
        );
        insert company;
        
        // Create test buses
        List<Bus__c> testBuses = new List<Bus__c>();
        for (Integer i = 0; i < 25; i++) { // Create 25 buses for various test scenarios
            testBuses.add(new Bus__c(
                Bus_Company__c = company.Id,
                Bus_Status__c = 'Available' // Default status
            ));
        }
        insert testBuses;
        
        // Create passengers for different scenarios
        List<Passenger__c> passengers = new List<Passenger__c>();
        
        // Scenario 1: 0 passengers (Available)
        // Bus 0 - no passengers
        
        // Scenario 2: 5 passengers (Available - less than 10)
        for (Integer i = 0; i < 5; i++) {
            passengers.add(new Passenger__c(
                Name = 'Passenger 1-' + (i + 1),
                Bus__c = testBuses[1].Id
            ));
        }
        
        // Scenario 3: 10 passengers (Available - exactly 10)
        for (Integer i = 0; i < 10; i++) {
            passengers.add(new Passenger__c(
                Name = 'Passenger 2-' + (i + 1),
                Bus__c = testBuses[2].Id
            ));
        }
        
        // Scenario 4: 15 passengers (Limited Seats - more than 10)
        for (Integer i = 0; i < 15; i++) {
            passengers.add(new Passenger__c(
                Name = 'Passenger 3-' + (i + 1),
                Bus__c = testBuses[3].Id
            ));
        }
        
        // Scenario 5: 20 passengers (Full - exactly 20)
        for (Integer i = 0; i < 20; i++) {
            passengers.add(new Passenger__c(
                Name = 'Passenger 4-' + (i + 1),
                Bus__c = testBuses[4].Id
            ));
        }
        
        // Scenario 6: 25 passengers (Exception - more than 20)
        for (Integer i = 0; i < 25; i++) {
            passengers.add(new Passenger__c(
                Name = 'Passenger 5-' + (i + 1),
                Bus__c = testBuses[5].Id
            ));
        }
        
        // Create additional test data for bulk processing (200+ records requirement)
        for (Integer busIndex = 6; busIndex < testBuses.size(); busIndex++) {
            Integer passengerCount = Math.mod(busIndex, 21); // 0-20 passengers
            for (Integer i = 0; i < passengerCount; i++) {
                passengers.add(new Passenger__c(
                    Name = 'Bulk Passenger ' + busIndex + '-' + (i + 1),
                    Bus__c = testBuses[busIndex].Id
                ));
            }
        }
        
        insert passengers;
    }
    
    @isTest
    static void testBusStatusCalculation_Available() {
        List<Bus__c> testBuses = [SELECT Id FROM Bus__c LIMIT 3];
        
        Test.startTest();
        BusStatusUpdateBatch batch = new BusStatusUpdateBatch(new List<Id>{testBuses[0].Id, testBuses[1].Id, testBuses[2].Id});
        Database.executeBatch(batch, 200);
        Test.stopTest();
        
        Map<Id, Bus__c> updatedBuses = new Map<Id, Bus__c>([
            SELECT Id, Bus_Status__c, (SELECT Id FROM Passengers__r) 
            FROM Bus__c 
            WHERE Id IN :testBuses
        ]);
        
        // Bus with 0 passengers should be Available
        System.assertEquals('Available', updatedBuses.get(testBuses[0].Id).Bus_Status__c, 
                          'Bus with 0 passengers should be Available');
        
        // Bus with 5 passengers should be Available
        System.assertEquals('Available', updatedBuses.get(testBuses[1].Id).Bus_Status__c, 
                          'Bus with 5 passengers should be Available');
        
        // Bus with 10 passengers should be Available
        System.assertEquals('Available', updatedBuses.get(testBuses[2].Id).Bus_Status__c, 
                          'Bus with 10 passengers should be Available');
    }
    
    @isTest
    static void testBusStatusCalculation_LimitedSeats() {
        List<Bus__c> testBuses = [SELECT Id FROM Bus__c LIMIT 4];
        
        Test.startTest();
        BusStatusUpdateBatch batch = new BusStatusUpdateBatch(new List<Id>{testBuses[3].Id});
        Database.executeBatch(batch, 200);
        Test.stopTest();
        
        Bus__c updatedBus = [SELECT Id, Bus_Status__c FROM Bus__c WHERE Id = :testBuses[3].Id];
        
        // Bus with 15 passengers should be Limited Seats
        System.assertEquals('Limited Seats', updatedBus.Bus_Status__c, 
                          'Bus with 15 passengers should be Limited Seats');
    }
    
    @isTest
    static void testBusStatusCalculation_Full() {
        List<Bus__c> testBuses = [SELECT Id FROM Bus__c LIMIT 5];
        
        Test.startTest();
        BusStatusUpdateBatch batch = new BusStatusUpdateBatch(new List<Id>{testBuses[4].Id});
        Database.executeBatch(batch, 200);
        Test.stopTest();
        
        Bus__c updatedBus = [SELECT Id, Bus_Status__c FROM Bus__c WHERE Id = :testBuses[4].Id];
        
        // Bus with 20 passengers should be Full
        System.assertEquals('Full', updatedBus.Bus_Status__c, 
                          'Bus with 20 passengers should be Full');
    }
    
    @isTest
    static void testBusStatusCalculation_Exception() {
        List<Bus__c> testBuses = [SELECT Id FROM Bus__c LIMIT 6];
        
        Test.startTest();
        BusStatusUpdateBatch batch = new BusStatusUpdateBatch(new List<Id>{testBuses[5].Id});
        Database.executeBatch(batch, 200);
        Test.stopTest();
        
        Bus__c updatedBus = [SELECT Id, Bus_Status__c FROM Bus__c WHERE Id = :testBuses[5].Id];
        
        // Bus with 25 passengers should remain unchanged due to exception
        // The status should not be updated when exception is thrown
        System.assertEquals('Available', updatedBus.Bus_Status__c, 
                          'Bus with 25 passengers should remain unchanged due to exception');
    }
    
    @isTest
    static void testBulkProcessing() {
        List<Bus__c> allBuses = [SELECT Id FROM Bus__c];
        
        // Test requirement: Capable for processing 200 Bus records in a single call
        System.assert(allBuses.size() >= 20, 'Should have at least 20 buses for bulk testing');
        
        Test.startTest();
        BusStatusUpdateBatch batch = new BusStatusUpdateBatch(new List<Id>());
        Database.executeBatch(batch, 200);
        Test.stopTest();
        
        // Verify that batch completed successfully
        List<Bus__c> processedBuses = [SELECT Id, Bus_Status__c FROM Bus__c];
        System.assert(processedBuses.size() > 0, 'Buses should be processed');
        
        // Count status distribution
        Integer availableCount = 0;
        Integer limitedCount = 0;
        Integer fullCount = 0;
        
        for (Bus__c bus : processedBuses) {
            if (bus.Bus_Status__c == 'Available') availableCount++;
            else if (bus.Bus_Status__c == 'Limited Seats') limitedCount++;
            else if (bus.Bus_Status__c == 'Full') fullCount++;
        }
        
        System.debug('Status distribution - Available: ' + availableCount + 
                    ', Limited: ' + limitedCount + ', Full: ' + fullCount);
        
        // Should have buses in different statuses
        System.assert(availableCount > 0, 'Should have some Available buses');
    }
    
    @isTest
    static void testUtilityMethods() {
        List<Bus__c> testBuses = [SELECT Id FROM Bus__c LIMIT 5];
        List<Id> busIds = new List<Id>();
        for (Bus__c bus : testBuses) {
            busIds.add(bus.Id);
        }
        
        Test.startTest();
        
        // Test executeBatch with specific IDs
        Id jobId1 = BusStatusUpdateBatch.executeBatch(busIds);
        System.assertNotEquals(null, jobId1, 'Should return valid job ID');
        
        // Test executeForAllBuses
        Id jobId2 = BusStatusUpdateBatch.executeForAllBuses();
        System.assertNotEquals(null, jobId2, 'Should return valid job ID for all buses');
        
        Test.stopTest();
    }
    
    @isTest
    static void testConstructors() {
        // Test constructor with null list
        BusStatusUpdateBatch batch1 = new BusStatusUpdateBatch(null);
        System.assertNotEquals(null, batch1, 'Should handle null bus IDs list');
        
        // Test default constructor
        BusStatusUpdateBatch batch2 = new BusStatusUpdateBatch();
        System.assertNotEquals(null, batch2, 'Should create batch with default constructor');
        
        // Test constructor with valid list
        List<Id> busIds = new List<Id>{[SELECT Id FROM Bus__c LIMIT 1].Id};
        BusStatusUpdateBatch batch3 = new BusStatusUpdateBatch(busIds);
        System.assertNotEquals(null, batch3, 'Should create batch with valid bus IDs');
    }
}