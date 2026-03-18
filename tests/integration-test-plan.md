# Integration Test Plan — Phase 1

**Goal:** Validate the full delegation loop: Mike → R. Sami → R. Daneel → R. Sammy → R. Daneel → R. Sami → Mike

**Run after:** `./setup.sh` completes and `openclaw gateway start` is running.

---

## Test 1 — Basic delegation round-trip

**Objective:** Confirm R. Daneel receives a task, routes it to R. Sammy, and returns a result.

**Input (sent from main session to coordinator):**
```
Task: Write a Python script that prints "Hello from R. Sammy" and the current timestamp.
Constraints: Save to /tmp/test_rsami.py and run it.
```

**Expected flow:**
```
R. Sami (main) 
  → sessions_send("session:coordinator-agent", task)
  → R. Daneel classifies: domain=python, agent=R. Sammy
  → sessions_send("session:python-dev-agent", payload)
  → R. Sammy writes /tmp/test_rsami.py, runs it, returns output
  → R. Daneel aggregates, sends summary to main session
  → R. Sami reports result to Mike
```

**Pass criteria:**
- [ ] R. Daneel responds within 60 seconds
- [ ] R. Sammy responds within 120 seconds
- [ ] `/tmp/test_rsami.py` exists on target machine
- [ ] Script output contains "Hello from R. Sammy" and a timestamp
- [ ] R. Daneel's summary is clean (not a raw dump)

---

## Test 2 — Timeout detection

**Objective:** Confirm R. Daneel detects a non-responsive agent and reports correctly.

**Input:** Send a task to a deliberately non-existent session key.

**Expected flow:**
```
R. Daneel dispatches → no response after 5 min
  → Logs timeout to memory/YYYY-MM-DD.md
  → Reports to main session:
    "⚠️ Agent timed out on task '...'. Should I dispatch R. Giskard / node agent?"
  → Waits for Mike's go-ahead
```

**Pass criteria:**
- [ ] Timeout message appears in main session within 6 minutes
- [ ] Message includes agent name, task name, elapsed time
- [ ] R. Daneel does NOT self-escalate

---

## Test 3 — Multi-agent parallel dispatch

**Objective:** Confirm R. Daneel can fan out to two agents simultaneously.

**Input:**
```
Task A (python): List all running Python processes on this machine
Task B (docker): List all running Docker containers
Run both in parallel and report combined results.
```

**Expected flow:**
```
R. Daneel classifies: two domains → parallel dispatch
  → sessions_send to R. Sammy (Task A)
  → sessions_send to R. Giskard (Task B)  ← simultaneously
  → Waits for both
  → Aggregates into one summary
  → Reports to main session
```

**Pass criteria:**
- [ ] Both agents receive tasks within seconds of each other
- [ ] R. Daneel waits for both before reporting
- [ ] Single aggregated summary delivered to main session

---

## Test 4 — Creative Director round-trip

**Objective:** Confirm R. Andrew receives and completes a content task.

**Input:**
```
Task: Write a two-sentence announcement for the OpenClaw Agent Co-ordinator project launch.
Audience: Technical blog readers.
```

**Pass criteria:**
- [ ] R. Andrew delivers title + content (not a draft note)
- [ ] Tone matches blog.repko.ca style
- [ ] No hedged/corporate language

---

## Running the tests

```bash
# After setup.sh and gateway start:
cd /opt/OpenclawAgent
./tests/run-integration-tests.sh
```

Results are logged to `/opt/OpenclawAgent/tests/results/YYYY-MM-DD.log`
