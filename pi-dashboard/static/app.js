const statusElement = document.querySelector("#status");
const totalElement = document.querySelector("#total-activations");
const studyElement = document.querySelector("#study-activations");
const gamingElement = document.querySelector("#gaming-activations");
const latestModeElement = document.querySelector("#latest-mode");
const latestDetailsElement = document.querySelector("#latest-details");
const eventsTable = document.querySelector("#events-table");
const refreshButton = document.querySelector("#refresh-button");

function text(value) {
  return value ?? "--";
}

function renderSummary(summary) {
  totalElement.textContent = summary.total_activations;
  studyElement.textContent = summary.study_activations;
  gamingElement.textContent = summary.gaming_activations;

  const latest = summary.latest_event;

  if (!latest) {
    latestModeElement.textContent = "--";
    latestDetailsElement.textContent = "No events received yet.";
    return;
  }

  latestModeElement.textContent = latest.mode;
  latestDetailsElement.textContent =
    `${latest.timestamp} on ${latest.computername}: ` +
    `${latest.estimatedfreedmb} MB (${latest.estimatedfreedgb} GB) estimated RAM freed.`;
}

function renderEvents(events) {
  eventsTable.replaceChildren();

  if (events.length === 0) {
    const row = document.createElement("tr");
    row.innerHTML = '<td colspan="4">No events received yet.</td>';
    eventsTable.append(row);
    return;
  }

  for (const event of events) {
    const row = document.createElement("tr");

    for (const value of [
      event.timestamp,
      event.mode,
      `${event.estimatedfreedmb} MB`,
      event.computername,
    ]) {
      const cell = document.createElement("td");
      cell.textContent = text(value);
      row.append(cell);
    }

    eventsTable.append(row);
  }
}

async function refreshDashboard() {
  refreshButton.disabled = true;
  statusElement.textContent = "Refreshing...";

  try {
    const [summaryResponse, eventsResponse] = await Promise.all([
      fetch("/api/summary"),
      fetch("/api/mode-events?limit=50"),
    ]);

    if (!summaryResponse.ok || !eventsResponse.ok) {
      throw new Error("The dashboard API did not respond successfully.");
    }

    const summary = await summaryResponse.json();
    const eventData = await eventsResponse.json();

    renderSummary(summary);
    renderEvents(eventData.events);
    statusElement.textContent = `Updated at ${new Date().toLocaleTimeString()}.`;
  } catch (error) {
    statusElement.textContent = `Could not load dashboard data: ${error.message}`;
  } finally {
    refreshButton.disabled = false;
  }
}

refreshButton.addEventListener("click", refreshDashboard);
refreshDashboard();