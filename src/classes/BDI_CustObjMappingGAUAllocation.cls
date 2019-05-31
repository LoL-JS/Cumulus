/*
    Copyright (c) 2014 Salesforce.org
    All rights reserved.
    
    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions are met:
    
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of Salesforce.org nor the names of
      its contributors may be used to endorse or promote products derived
      from this software without specific prior written permission.
 
    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
    "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT 
    LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS 
    FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE 
    COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, 
    INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, 
    BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; 
    LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER 
    CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT 
    LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN 
    ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
    POSSIBILITY OF SUCH DAMAGE.
*/
/**
* @author Salesforce.org
* @date 2019
* @group Batch Data Import
* @group-content ../../ApexDocContent/BatchDataImport.htm
* @description Overrides the standard object mapping logic class for GAU allocation field mapping since only one of
* the Opportunity__c, Payment__c and Campaign__c fields should be populated.
*/

public with sharing class BDI_CustObjMappingGAUAllocation extends BDI_ObjectMappingLogic {

    public override BDI_ObjectWrapper[] populateObjects(BDI_ObjectWrapper[] objWraps) {

        Allocations_Settings__c settings = UTIL_CustomSettingsFacade.getAllocationsSettings();

        Map<String, Schema.DescribeFieldResult> sourceFieldDescribeMap = UTIL_Describe.getAllFieldsDescribe(UTIL_Namespace.adjustNPSPNamespace('npsp__DataImport__c'));

        String PAYMENT_FIELDNAME = 'npsp__Payment__c';
        String OPPORTUNITY_FIELDNAME = 'npsp__Opportunity__c';
        String CAMPAIGN_FIELDNAME = 'npsp__Campaign__c';

        for (BDI_ObjectWrapper objWrap : objWraps) {
            Map<String, Schema.DescribeFieldResult> fieldDescribeMap = UTIL_Describe.getAllFieldsDescribe(UTIL_Namespace.adjustNPSPNamespace(objWrap.objMapping.Object_API_Name__c));

            objWrap.sObj = Schema.getGlobalDescribe().get(UTIL_Namespace.adjustNPSPNamespace(objWrap.objMapping.Object_API_Name__c)).newSObject();

            if (objWrap.existingSObjectId != null) {
                objWrap.sObj.put('Id', objWrap.existingSObjectId);
            }

            Object campaignValue;
            Object paymentValue;
            Object opportunityValue;

            for (Data_Import_Field_Mapping__mdt fieldMapping : objWrap.fieldMappings) {
                String sourceFieldName = UTIL_Namespace.adjustNPSPNamespace(fieldMapping.Source_Field_API_Name__c);
                String targetFieldName = UTIL_Namespace.adjustNPSPNamespace(fieldMapping.Target_Field_API_Name__c);

                Object value = objWrap.dataImport.get(sourceFieldName);

                Schema.DescribeFieldResult sourceFieldDescribe = sourceFieldDescribeMap.get(sourceFieldName.toLowerCase());
                Schema.DescribeFieldResult targetFieldDescribe = fieldDescribeMap.get(targetFieldName.toLowerCase());

                //Confirm that it is real field, and that it is accessible to the running user.
                if (targetFieldDescribe != null && targetFieldDescribe.isAccessible()) {
                    //Confirm that either the sObj Id is null (ie new record) or that the field is updatable if it is not new.
                    if (objWrap.sObj.Id == null || targetFieldDescribe.isUpdateable()) {
                        // If the target field mapping is one of the key parent objects, then extract the values for later logic
                        if (fieldMapping.Target_Field_API_Name__c == PAYMENT_FIELDNAME) {
                            paymentValue = value;
                        } else if (fieldMapping.Target_Field_API_Name__c == OPPORTUNITY_FIELDNAME) {
                            opportunityValue = value;
                        } else if (fieldMapping.Target_Field_API_Name__c == CAMPAIGN_FIELDNAME) {
                            campaignValue = value;
                        } else {
                            castAndCopyField(objWrap, sourceFieldName, sourceFieldDescribe, targetFieldName, targetFieldDescribe);
                        }
                    }
                }
            }

            // If the payment is specified and payment allocations are enabled, always use that first.
            if ( paymentValue != null && settings.Payment_Allocations_Enabled__c) {
                objWrap.sObj.put(UTIL_Namespace.adjustNPSPNamespace(PAYMENT_FIELDNAME),paymentValue);
            } else if ( opportunityValue != null ) {
                objWrap.sObj.put(UTIL_Namespace.adjustNPSPNamespace(OPPORTUNITY_FIELDNAME),opportunityValue);
            } else if ( campaignValue != null ) { 
                objWrap.sObj.put(UTIL_Namespace.adjustNPSPNamespace(CAMPAIGN_FIELDNAME),campaignValue);
            }

        }
        return objWraps;
    }
}