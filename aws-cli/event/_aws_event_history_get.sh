#!/bin/bash

output_format='json'
aws_region='us-east-1'
filename_out="aws_log_history_events.${output_format}"

# YYYY-MM-DDTHH:MM:SSZ
event_time_start="2023-10-02T00:00"
event_time_end="2023-10-03T23:59"

#"EventId"|"EventName"|"ReadOnly"|"Username"|"ResourceType"|"ResourceName"|"EventSource"|"AccessKeyId"
# aws_log_attr_name='ResourceType'
# aws_log_attr_val='AWS::EC2::Instance'
# aws_log_querry='Events[].}'

aws_log_attr_name='EventName'
aws_log_attr_val='RunInstances'
aws_log_querry='Events[].{UserName: Username, EventName: EventName, EventTime: EventTime, CloudTrailEvent: CloudTrailEvent}'
#aws_log_querry='Events[].{UserName: Username, EventName: EventName, EventTime: EventTime, CloudTrailEvent: CloudTrailEvent} | sort_by(@, &EventTime) | [0]'

aws_log_attr="AttributeKey=${aws_log_attr_name},AttributeValue=${aws_log_attr_val}"

aws cloudtrail lookup-events \
    --region ${aws_region} \
    --start-time "${event_time_start}" \
    --end-time "${event_time_end}" \
    --lookup-attributes "${aws_log_attr}" \
    --query "${aws_log_querry}" \
    --output "${output_format}" \
    > "${filename_out}"
