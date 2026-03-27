# ✅ Todo App — DevSecOps, Docker, GitLab CI/CD & AWS (Terraform)

A learning/portfolio project that demonstrates how to build, test, containerize, and deploy a simple **Node.js + Express Todo application** using:

- **Automated tests** (Jest + Supertest)
- **Docker** containerization
- **GitLab CI/CD** (build → test → security → package → deploy)
- **AWS deployment with Terraform** (ECR + ECS Fargate + ALB + CloudWatch)

This project is intentionally small in business scope (task manager), but strong in **software engineering / DevSecOps practices**.

---

## 📌 Project Highlights

- ✅ Full-stack Todo app (Express backend + static frontend)
- ✅ REST API for task CRUD (create/list/get/delete)
- ✅ Local JSON file persistence (`DB/Tasks.json`)
- ✅ Automated API tests (Jest + Supertest)
- ✅ Dockerized app (Node 20 Alpine)
- ✅ GitLab CI/CD pipeline with:
  - build
  - test
  - security scans (`npm audit`, `gitleaks`)
  - Docker image packaging/push
  - deploy stages
- ✅ Terraform infrastructure for AWS:
  - VPC + public subnets
  - Security groups
  - ECR repository
  - ECS cluster/service (Fargate)
  - ALB + target group + health checks
  - CloudWatch log group
  - IAM execution role

---

## 🧭 Why this project matters

This repository is more than a “Todo app” demo. It is a **learning project for application testing, CI/CD, Docker, and cloud deployment**, showing an end-to-end workflow from local development to container runtime on AWS.

It is useful for recruiters/visitors who want to see:
- backend fundamentals,
- test automation,
- pipeline troubleshooting,
- container workflows,
- Infrastructure as Code (Terraform),
- deployment thinking and production-readiness tradeoffs.

---

## 🛠️ Tech Stack

### Application
- **Node.js 20.x**
- **Express**
- **HTML / CSS / JavaScript (Fetch API)**

### Testing
- **Jest**
- **Supertest**

### DevOps / Security
- **Docker**
- **GitLab CI/CD**
- **Gitleaks** (secret scanning)
- **npm audit** (dependency scanning)

### Cloud / IaC
- **AWS**
  - ECR
  - ECS Fargate
  - ALB
  - CloudWatch Logs
  - IAM
  - VPC networking
- **Terraform**

---

## 📁 Repository Structure

~~~text
ToDo-app/
├── DB/
│   └── Tasks.json              # Local JSON datastore
├── infra/                      # Terraform infrastructure (AWS)
│   ├── main.tf
│   ├── .terraform/             # Generated locally (should not be committed)
│   └── terraform.tfstate*      # Local state (should not be committed)
├── public/
│   ├── index.html              # UI
│   ├── style.css               # Styling
│   └── app.js                  # Front-end logic (fetch/search/sort/delete)
├── tests/
│   └── tasks.test.js           # Jest + Supertest API tests
├── .dockerignore
├── .gitignore
├── .gitlab-ci.yml              # GitLab pipeline
├── .terraform.lock.hcl
├── app.js                      # Express app + API routes
├── Dockerfile
├── package.json
└── package-lock.json
~~~

> ⚠️ Note: Folders like `.terraform/` and files like `terraform.tfstate` are generated locally and should not be committed to Git in a production-grade setup.

---

## ✨ Features

### Backend API
- List all tasks
- Get a task by ID
- Create a task
- Delete a task

### Frontend UI
- Add task form (`title` + `content`)
- Task list cards
- Search/filter tasks
- Sort tasks (Newest / Oldest / A→Z / Z→A)
- Refresh button
- Status messages (loading / success / error)

### Persistence model (training-friendly)
Tasks are stored in `DB/Tasks.json`, which keeps setup simple and makes the project easy to run locally.

> ⚠️ This is **not production-grade persistence** (see limitations section below).

---

## 🚀 Quick Start (Local Development)

### 1) Clone the repository

~~~bash
git clone https://github.com/Simo-Zg/ToDo-app.git
cd ToDo-app
~~~

### 2) Install dependencies

~~~bash
npm install
~~~

### 3) Run the app

~~~bash
npm start
~~~

The app starts on:

- **http://127.0.0.1:5000**
- (also usually reachable at `http://localhost:5000`)

### 4) Development mode (auto-reload)

~~~bash
npm run dev
~~~

---

## 🧪 Run Tests

### Run test suite (Jest + Supertest)

~~~bash
npm test
~~~

### Watch mode

~~~bash
npm run test-watch
~~~

### What is tested?
The test suite validates core API behavior:
- `POST /api/task` creates a task
- `GET /api/tasks` returns tasks
- `DELETE /api/task/:id` deletes a task

The tests reset `DB/Tasks.json` before each test to avoid order dependency and keep test runs deterministic.

---

## 📡 API Reference

Base URL (local): `http://localhost:5000`

### `GET /api/tasks`
Returns all tasks.

**Response**
~~~json
[
  {
    "id": "uuid",
    "title": "My task",
    "content": "Task details",
    "date": 1739999999999
  }
]
~~~

---

### `GET /api/task/:id`
Returns a task by ID.

**Success (200)**
~~~json
{
  "id": "uuid",
  "title": "My task",
  "content": "Task details",
  "date": 1739999999999
}
~~~

**Not found (404)**
~~~json
{ "error": "Task not found" }
~~~

---

### `POST /api/task`
Creates a task.

**Request body**
~~~json
{
  "title": "Study CI/CD",
  "content": "Finish pipeline documentation"
}
~~~

**Success (201)**
~~~json
{
  "id": "generated-uuid",
  "title": "Study CI/CD",
  "content": "Finish pipeline documentation",
  "date": 1739999999999
}
~~~

**Validation error (400)**
~~~json
{ "error": "Title and content required" }
~~~

---

### `DELETE /api/task/:id`
Deletes a task by ID.

**Success (200)**
~~~json
{ "success": true }
~~~

**Not found (404)**
~~~json
{ "error": "Task not found" }
~~~

---

## 🧪 Useful `curl` Examples

### Create a task
~~~bash
curl -X POST http://localhost:5000/api/task \
  -H "Content-Type: application/json" \
  -d "{\"title\":\"Learn Terraform\",\"content\":\"Provision ECS Fargate infra\"}"
~~~

### List tasks
~~~bash
curl http://localhost:5000/api/tasks
~~~

### Get one task
~~~bash
curl http://localhost:5000/api/task/<TASK_ID>
~~~

### Delete a task
~~~bash
curl -X DELETE http://localhost:5000/api/task/<TASK_ID>
~~~

---

## 🐳 Docker (Local Container Run)

### Build the image
~~~bash
docker build -t todo-app:1.0.0 .
~~~

### Run the container
~~~bash
docker run --rm -p 5000:5000 todo-app:1.0.0
~~~

Then open:
- `http://localhost:5000`

### (Optional) Persist JSON data outside the container

Because the app stores data in `/app/DB/Tasks.json`, you can mount the `DB` folder from your host.

#### Linux / macOS (bash)
~~~bash
docker run --rm -p 5000:5000 -v "$(pwd)/DB:/app/DB" todo-app:1.0.0
~~~

#### Windows PowerShell
~~~powershell
docker run --rm -p 5000:5000 -v "${PWD}\DB:/app/DB" todo-app:1.0.0
~~~

> This is useful during development; otherwise data created in the container is lost when the container is removed.

---

## 🔁 GitLab CI/CD Pipeline

The project includes a GitLab CI pipeline (`.gitlab-ci.yml`) with stages such as:

1. **build**
   - install dependencies
   - syntax checks

2. **test**
   - run Jest tests

3. **security**
   - dependency scan (`npm audit`)
   - secret scan (`gitleaks`)

4. **package**
   - build Docker image
   - tag and push image to registry

5. **deploy**
   - deployment jobs (depending on your runner/environment setup)

### Why the registry step is important
CI jobs are isolated. A Docker image built in one job is **not automatically available** in another job.

Correct pattern:
- build image in package job,
- push it to a registry,
- pull it in deploy job(s).

### CI security notes
- `gitleaks` helps detect accidentally committed secrets.
- `npm audit` checks for known vulnerable dependencies.
- Image names/tags should be registry-safe and lowercase.

---

## ☁️ AWS Deployment with Terraform (ECS Fargate)

This repository also contains an `infra/` folder with Terraform infrastructure for AWS.

### Architecture (high level)

~~~text
Browser
  ↓
Application Load Balancer (HTTP)
  ↓
Target Group
  ↓
ECS Service (Fargate)
  ↓
Node.js Todo App container
  ↓
CloudWatch Logs
~~~

Supporting resources include:
- VPC + public subnets + route table + internet gateway
- Security groups (ALB and ECS task)
- ECR repository
- IAM task execution role

---

## ☁️ AWS Deployment Walkthrough (Recommended)

### Prerequisites
- AWS account
- AWS CLI configured
- Terraform installed
- Docker installed

### 1) Initialize Terraform
~~~bash
cd infra
terraform init
~~~

### 2) First apply (create infra)
~~~bash
terraform apply
~~~

> In many learning setups, the ECS service may initially be configured with `desired_count = 0` until the container image is pushed to ECR.

### 3) Get Terraform outputs
Use Terraform outputs to retrieve values such as:
- `alb_url`
- `ecr_repository_url`
- `ecs_cluster_name`

Example:
~~~bash
terraform output
~~~

### 4) Authenticate Docker to ECR
~~~bash
aws ecr get-login-password --region eu-west-3 | docker login --username AWS --password-stdin <AWS_ACCOUNT_ID>.dkr.ecr.eu-west-3.amazonaws.com
~~~

### 5) Build and push the image to ECR
Make sure the image tag matches the Terraform variable (for example `v1`).

~~~bash
docker build -t todo-app:v1 .
docker tag todo-app:v1 <ECR_REPOSITORY_URL>:v1
docker push <ECR_REPOSITORY_URL>:v1
~~~

### 6) Scale the ECS service to 1 task (if needed)
~~~bash
terraform apply -var="desired_count=1"
~~~

### 7) Open the app
Use the `alb_url` Terraform output in your browser.

---

## ⚠️ Limitations (Honest Engineering Notes)

This project is intentionally designed as a learning/portfolio app. Current limitations:

### 1) JSON file storage (local filesystem)
- not safe for concurrent writes,
- full file rewrite on each update,
- not horizontally scalable.

### 2) Fargate storage is ephemeral
When running on ECS Fargate, local container files are ephemeral by default:
- data may be lost on restart/redeploy,
- multiple tasks do not share the same file state.

### 3) HTTP only (no TLS yet)
The ALB may be configured with HTTP only (port 80) in the learning version.  
Production-ready improvement:
- AWS ACM certificate
- HTTPS listener (443)
- optional HTTP → HTTPS redirect

### 4) Local Terraform state
Using local state is common for learning, but production practice is:
- S3 backend
- state locking
- versioning/backup

---

## 🧠 What I Learned (Project Value)

This project helped me practice and understand:

- API design and testing with Jest + Supertest
- Docker image build/run workflows
- CI job isolation and registry-based image promotion
- GitLab pipeline troubleshooting
- Terraform-based AWS provisioning
- ECS Fargate + ALB deployment flow
- cloud tradeoffs (ephemeral storage, TLS, state management)

---

## 🚧 Suggested Next Improvements (High Value)

### Application
- [ ] Add `PUT /api/task/:id` (update task)
- [ ] Add task status (`todo / doing / done`)
- [ ] Add due dates and validation rules
- [ ] Pagination for large task lists
- [ ] Better input validation (length limits, sanitization)

### Testing
- [ ] Add negative tests (missing fields, invalid IDs)
- [ ] Add route-level error handling tests
- [ ] Add coverage report publishing in CI
- [ ] Add frontend integration tests

### Security
- [ ] Add rate limiting
- [ ] Add Helmet middleware
- [ ] Add structured logging
- [ ] Add SAST/dependency reports as CI artifacts

### Docker / Runtime
- [ ] Multi-stage Docker build
- [ ] Run app as non-root user
- [ ] Add Docker healthcheck
- [ ] `.env` config support

### AWS / Production-readiness
- [ ] Replace JSON storage with DynamoDB or RDS
- [ ] Add HTTPS (ACM + ALB 443)
- [ ] Remote Terraform state (S3 + locking)
- [ ] CloudWatch dashboards/alarms
- [ ] ECS auto-scaling
- [ ] CI deployment to ECS directly

---

## 📸 Screenshots (Recommended for the Repo)

To make this repo even stronger for visitors, add a `docs/` folder and include:
- `docs/screenshots/ui.png` (Todo app UI)
- `docs/screenshots/tests.png` (Jest passing tests)
- `docs/screenshots/gitlab-pipeline.png` (pipeline view)
- `docs/screenshots/aws-ecs.png` (ECS cluster/service)
- `docs/screenshots/aws-ecr.png` (ECR repository)
- `docs/screenshots/aws-live-alb.png` (live app behind ALB)

Example section:

~~~md
## Screenshots

### UI
![Todo App UI](docs/screenshots/ui.png)

### Tests
![Jest Tests](docs/screenshots/tests.png)

### GitLab Pipeline
![Pipeline](docs/screenshots/gitlab-pipeline.png)
~~~

---

## 👤 Author

**Mohammed ZGUIOUI**

- GitHub: [Simo-Zg](https://github.com/Simo-Zg)

---

## 📄 License

This project is currently provided as a learning/portfolio project.

You can add a license file (for example **MIT**) to clarify reuse permissions.

---

## 🙌 Acknowledgment

Built as a university learning project to practice:
- application development,
- testing,
- Docker,
- CI/CD,
- and AWS cloud deployment with Terraform.