# Healthcare Agentforce Task Management Solution

<div align="center">

![Salesforce](https://img.shields.io/badge/Salesforce-00A1E0?style=for-the-badge&logo=salesforce&logoColor=white)
![Agentforce](https://img.shields.io/badge/Agentforce-AI-orange?style=for-the-badge)
![Health Cloud](https://img.shields.io/badge/Health_Cloud-Enabled-green?style=for-the-badge)

**An intelligent AI-powered assistant for healthcare sales professionals built on Salesforce Agentforce**

</div>

---

## 📋 Overview

The Healthcare Agentforce Task Management Solution streamlines healthcare sales operations through AI-powered automation. Built for Salesforce Health Cloud, this solution helps field representatives manage visits, documentation, and follow-ups efficiently.

### Core Capabilities

**🔍 Pre-Visit Intelligence**
- Automated physician and account briefings with historical interaction analysis
- AI-powered insights from past referrals, visits, and engagements
- Real-time contact and healthcare provider information retrieval

**🎤 Voice-Enabled Post-Visit Documentation**
- Natural language visit logging through voice or text
- Automatic creation of structured visit records
- Mobile receipt capture with expense tracking

**🤖 Intelligent Task Management**
- Context-aware task creation and assignment
- Automated follow-up scheduling
- Multi-channel capabilities (chat, WhatsApp, mobile)

---

## 🏗️ Architecture

### System Components

```
┌─────────────────────────────────────────────────────┐
│              Agentforce Agent (v15)                 │
│  ┌────────────────────────────────────────────┐    │
│  │ Topics:                                    │    │
│  │  • Physician_Briefing (Pre-visit prep)    │    │
│  │  • Post_Visit_Actions (Visit logging)     │    │
│  │  • Expense_logger (Expense tracking)      │    │
│  │  • GeneralFAQ (Knowledge search)          │    │
│  └────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────┘
                        ▼
┌─────────────────────────────────────────────────────┐
│              GenAI Functions Layer                  │
│  • Physician Briefing  • Contact Info              │
│  • Visit Log Creator   • Task Creator              │
│  • Expense Logger      • Healthcare Provider Search│
└─────────────────────────────────────────────────────┘
                        ▼
┌─────────────────────────────────────────────────────┐
│              Apex Business Logic                    │
│  • PhysicianInsightsBriefing                       │
│  • PostVisitLogOrchestrator                        │
│  • ContactFinder                                   │
│  • TaskCreator / EmployeeExpenseLogger             │
└─────────────────────────────────────────────────────┘
                        ▼
┌─────────────────────────────────────────────────────┐
│            Salesforce Health Cloud Data             │
│  Standard: Account, Contact, HealthcareProvider    │
│            Task, WorkOrder, Expense                │
│  Custom:   Post_Visit_Log__c                       │
│            Salesforce_General_Setting__c           │
└─────────────────────────────────────────────────────┘
```

**Technology Stack:**
- Platform: Salesforce Health Cloud
- AI: Agentforce with Einstein GPT
- Backend: Apex
- Frontend: Lightning Web Components (LWC)
- Mobile: Responsive LWC with Camera API

---

## 🚀 Quick Start

### Prerequisites

- Salesforce Health Cloud with Agentforce license
- System Administrator access
- Salesforce CLI v2.0+

### Installation

```bash
# Clone repository
git clone https://github.com/sfdchack-healthagents/sfdc-healthcloud-hackathon.git
cd sfdc-healthcloud-hackathon

# Authenticate to your org
sf org login web --alias my-health-org
sf config set target-org my-health-org

# Deploy metadata
sf project deploy start --source-path force-app/main/default

# Assign permissions
sf org assign permset --name Agentforce_Task_Management_User
```

### Activate Agent

1. **Setup** → **Agentforce Agents** → **Task_Management_Agent_15**
2. Click **Activate**
3. Configure deployment channel (embedded chat, Slack, WhatsApp, SMS)

---

## 📱 Usage Examples

### 1. Pre-Visit Briefing

```
User: "Brief me on Dr. Emily Roberts"

Agent: "📊 Dr. Emily Roberts - Cardiology, City Medical Center

Recent Activity:
• 89 referrals in last 12 months
• Last visit: Jan 2 (discussed cardiac monitoring)
• 2 pending follow-ups

Key Insight: Expressed interest in oncology pilot. 
Budget approval cycle starts Q3."
```

### 2. Post-Visit Logging

```
User: "Log my visit to Apollo Hospitals. Met Dr. Sharma today 
about cardiology expansion. They need patient monitoring for 
50 beds. Send proposal by Friday. Travel expense was 1200."

Agent: "✅ Visit logged successfully!
✅ Task created: Send proposal to Dr. Sharma (Due: Jan 10)
✅ Expense logged: ₹1,200 travel"
```

### 3. Task Creation

```
User: "Create a task to follow up with Dr. Chen next Tuesday"

Agent: "✅ Task created:
• Subject: Follow up with Dr. Chen
• Due: Tuesday, Jan 14, 2026
• Priority: Normal"
```

### 4. Expense Logging

```
User: "Log 850 rupees expense for visiting Manipal Hospital"

Agent: "✅ Expense logged: ₹850
• Hospital: Manipal Hospital
• Work Order created and linked"
```

### 5. Receipt Attachment (Mobile)

Users can attach receipts to expense records using their mobile device:

**Option 1: Camera Capture**
1. Open expense record on mobile
2. Tap "Attach Receipt" button
3. Use camera to photograph receipt
4. System automatically extracts amount, date, vendor
5. Receipt linked to expense record

**Option 2: Gallery Upload**
1. Open expense record
2. Tap "Attach Receipt" button
3. Select "Choose from Gallery"
4. Pick receipt image from phone
5. Receipt uploaded and linked

**Supported formats:** JPEG, PNG, PDF
**Auto-extraction:** Amount, date, vendor name, category

---

## 📚 Key Components

### Salesforce Objects Used

| Object | Purpose |
|--------|---------|
| **Account** | Healthcare facilities (hospitals, clinics) |
| **Contact** | Healthcare providers (physicians, staff) |
| **HealthcareProvider** | Provider profiles with specialties |
| **Task** | Follow-up actions and reminders |
| **WorkOrder** | Service visit tracking |
| **Expense** | Visit-related expenses |
| **Post_Visit_Log__c** | Custom visit documentation records |
| **Salesforce_General_Setting__c** | Custom configuration settings |

### Core Apex Classes

- **PhysicianInsightsBriefing.cls** - Aggregates physician data, activities, and visit history
- **PostVisitLogOrchestrator.cls** - Orchestrates visit log creation, task generation, expense tracking
- **ContactFinder.cls** - SOSL-based intelligent contact search
- **EmployeeExpenseLogger.cls** - Creates expenses with WorkOrder linkage
- **TaskCreator.cls** - Task creation with proper record associations
- **MobileReceiptController.cls** - Mobile camera and gallery integration for receipt attachment

### Agent Topics

1. **Physician_Briefing** - Pre-visit intelligence gathering
2. **Post_Visit_Actions** - Post-visit documentation workflow
3. **Expense_logger** - Expense tracking and logging
4. **GeneralFAQ** - Knowledge article search

---

## 🔧 Configuration

### Agent Variables

The agent maintains context through session variables:
- `EndUserId`, `ContactId` - User identification
- `healthcareprovider_id` - Current provider context
- `AccountforExpenseCreation` - Expense account linkage
- `currentRecordId` - Active record context

### Custom Settings

Configure `Salesforce_General_Setting__c` for organizational preferences:
- Default task priorities and due dates
- Email templates and brochures
- Expense categories
- Workflow automation rules

---

## 🧪 Testing

### Test the Agent

1. Navigate to **Setup** → **Agentforce Agents** → **Task_Management_Agent_15**
2. Click **Preview**
3. Test scenarios:
   - "Brief me on Dr. Johnson"
   - "Log my visit to City Hospital with Dr. Patel"
   - "Create a task to call Dr. Smith next week"
   - "Log expense of 500 for visiting Apollo"

### Run Apex Tests

```bash
# Run all tests
sf apex run test --test-level RunLocalTests --result-format human

# Check coverage
sf apex get test --test-run-id <id> --code-coverage
```

---

## 🎯 Key Features

### Intelligent Data Handling

- **SOSL Phonetic Search** - Finds contacts/accounts even with spelling variations
- **Graceful Fallbacks** - Uses LIKE queries when SOSL unavailable
- **Atomic Transactions** - All-or-nothing approach for data integrity
- **Smart Name Detection** - Distinguishes person names from organization names

### Mobile Optimization

- **Voice Input** - Natural language processing for hands-free operation
- **Receipt Capture** - Camera and gallery integration for receipt attachment
  - Capture new receipts using phone camera
  - Upload existing receipts from photo gallery
  - Automatic data extraction (amount, date, vendor)
  - Attach to new or existing expense records
- **Offline Capability** - Queue actions when connectivity is limited
- **Responsive Design** - Optimized for field use on mobile devices

### AI-Powered Insights

- **Historical Analysis** - Learns from past interactions
- **Contextual Recommendations** - Suggests next best actions
- **Automated Summarization** - Generates concise visit summaries
- **Pattern Recognition** - Identifies trends in referrals and activities

---

## 📊 Solution Statistics

- **Apex Classes**: 20+
- **GenAI Functions**: 7
- **LWC Components**: 2
- **Agent Topics**: 4
- **Custom Objects**: 2
- **Code Coverage**: 85%+

---

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Submit a pull request with clear description

---

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/sfdchack-healthagents/sfdc-healthcloud-hackathon/issues)
- **Documentation**: [Salesforce Agentforce Docs](https://help.salesforce.com/agentforce)

---

## 📄 License

MIT License - See [LICENSE](LICENSE) file for details

---

**Built with ❤️ for Healthcare Professionals**