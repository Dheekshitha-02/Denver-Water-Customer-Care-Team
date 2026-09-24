Denver Water AI Agent Assist POC - Synthetic Data

Purpose
-------
Synthetic data for demonstrating the proposed Genesys + Oracle CC&B data flow.
All names, phone numbers, emails, account numbers, addresses, transactions and events are fictional.
This is NOT Denver Water production data and is NOT a reproduction of Denver Water's actual database schema.

Suggested Supabase schemas
--------------------------
genesys_mock
ccb_mock

Important design choices
------------------------
1. CC&B customers are generated first.
2. Genesys interactions deliberately reuse synthetic customer phone/email values so dbt can resolve cross-system context.
3. No database foreign keys should be created between genesys_mock and ccb_mock; they simulate separate source systems.
4. Payment data contains no card numbers, bank account numbers, CVVs, or other payment credentials.
5. Genesys transcript rows are simulated POC input. Denver Water stated real-time transcription is not currently enabled.
6. Wrap-up codes and table structures are POC synthetic designs and must not be presented as Denver Water's actual production taxonomy/schema.

Key demo scenarios
------------------
ACC0001 / PER0001: High bill + sharp consumption spike + prior irrigation note.
ACC0002 / PER0002: No-water call + urgent dispatched field activity.
ACC0003 / PER0003: Lead Reduction Program + replacement scheduled.
ACC0004 / PER0004: Recent payment posting/status.
ACC0005 / PER0005: Transfer-of-service history.
ACC0006 / PER0006: Meter question + unusually low usage.
ACC0007 / PER0007: Outage-style inquiry.
ACC0008 / PER0008: High usage + scheduled High Usage Investigation.

Recommended loading order
-------------------------
ccb_persons
ccb_accounts
ccb_account_persons
ccb_premises
ccb_service_points
ccb_meters
ccb_bills
ccb_payments
ccb_consumption
ccb_contact_notes
ccb_field_activities
ccb_service_history
ccb_lead_program
genesys_users
genesys_queues
genesys_wrap_up_codes
genesys_interactions
genesys_participants
genesys_transcripts
