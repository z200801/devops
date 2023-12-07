#!/bin/bash

output_format="text"
instances_id=$(aws ec2 describe-instances --query 'Reservations[].Instances[?State.Name==`running`].[InstanceId]' --output text)

if [ -z "${instances_id}" ]; then echo "Not running instances. Exiting"; exit 1; fi

for id in ${instances_id}; do
 echo "Instance: [${id}]"
 echo "Metrics:"
 #aws cloudwatch list-metrics --dimensions Name=InstanceId,Value="${id}" --output "${output_format}"

 aws cloudwatch get-metric-data \
  --metric-data-queries '[{"Id": "m1", "MetricStat": {"Metric": {"Namespace": "AWS/EC2", "MetricName": "CPUUtilization", "Dimensions": [{"Name": "InstanceId", "Value": "${instance_id}"}]}, "Period": 300, "Stat": "Average"}, "ReturnData": true}]' \
  --start-time 2023-10-24T00:00:00Z \
  --end-time 2023-10-24T23:59:59Z
done

