trigger PassengerCounterTrigger on Passenger__c (before insert, before update) {
    Set<Id> busIds = new Set<Id>();
    
    // Collect all Bus__c Ids from the passenger records being inserted or updated
    for (Passenger__c passenger : Trigger.new) {
        if (passenger.Bus__c != null) {
            busIds.add(passenger.Bus__c);
        }
    }
    
    if (busIds.isEmpty()) {
        return; // No buses to check
    }
    
    // Query existing passengers count for each bus
    Map<Id, Integer> existingBusPassengerCount = new Map<Id, Integer>();
    
    for (AggregateResult result : [SELECT Bus__c, COUNT(Id) passengerCount
                                   FROM Passenger__c 
                                   WHERE Bus__c IN :busIds
                                   GROUP BY Bus__c]) {
        existingBusPassengerCount.put((Id)result.get('Bus__c'), (Integer)result.get('passengerCount'));
    }
    
    // Track passengers being added to each bus in this transaction
    Map<Id, Integer> newPassengersPerBus = new Map<Id, Integer>();
    
    // Count passengers being inserted/moved to each bus in this transaction
    for (Passenger__c passenger : Trigger.new) {
        if (passenger.Bus__c == null) {
            continue;
        }
        
        Boolean isNewPassengerForBus = Trigger.isInsert;
        
        if (Trigger.isUpdate) {
            Passenger__c oldPassenger = Trigger.oldMap.get(passenger.Id);
            isNewPassengerForBus = (oldPassenger.Bus__c != passenger.Bus__c);
        }
        
        if (isNewPassengerForBus) {
            Integer currentNewCount = newPassengersPerBus.get(passenger.Bus__c);
            if (currentNewCount == null) {
                currentNewCount = 0;
            }
            newPassengersPerBus.put(passenger.Bus__c, currentNewCount + 1);
        }
    }
    
    // Validate each passenger against the combined count (existing + new in this transaction)
    Map<Id, Integer> processedPassengersPerBus = new Map<Id, Integer>();
    
    for (Passenger__c passenger : Trigger.new) {
        if (passenger.Bus__c == null) {
            continue;
        }
        
        Boolean isNewPassengerForBus = Trigger.isInsert;
        
        if (Trigger.isUpdate) {
            Passenger__c oldPassenger = Trigger.oldMap.get(passenger.Bus__c);
            isNewPassengerForBus = (oldPassenger.Bus__c != passenger.Bus__c);
        }
        
        if (isNewPassengerForBus) {
            // Get existing passenger count
            Integer existingCount = existingBusPassengerCount.get(passenger.Bus__c);
            if (existingCount == null) {
                existingCount = 0;
            }
            
            // Track how many we've processed for this bus so far in this transaction
            Integer processedCount = processedPassengersPerBus.get(passenger.Bus__c);
            if (processedCount == null) {
                processedCount = 0;
            }
            processedCount++;
            processedPassengersPerBus.put(passenger.Bus__c, processedCount);
            
            // Calculate total: existing + passengers processed so far in this transaction
            Integer totalCount = existingCount + processedCount;
            
            if (totalCount > 20) {
                passenger.addError('A bus cannot have more than 20 passengers. ' +
                                 'This bus would have ' + totalCount + ' passengers ' +
                                 '(' + existingCount + ' existing + ' + processedCount + ' being added).');
            }
        }
    }
}