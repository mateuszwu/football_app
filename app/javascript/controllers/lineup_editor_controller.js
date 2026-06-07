import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = [
    "pool",
    "teamA",
    "teamB",
    "teamWaiting",
    "teamAInputs",
    "teamBInputs",
    "teamWaitingInputs",
  ];
  static values = {
    teamAPlayerIds: Array,
    teamBPlayerIds: Array,
    teamWaitingPlayerIds: Array,
  };

  connect() {
    if (this.element.dataset.lineupInitialized === "true") return;

    this.element.dataset.lineupInitialized = "true";

    // Initialize state from dataset
    this.state = {
      teamA: (this.teamAPlayerIdsValue || []).map(String),
      teamB: (this.teamBPlayerIdsValue || []).map(String),
      teamWaiting: (this.teamWaitingPlayerIdsValue || []).map(String),
    };

    // Setup listeners for checkbox changes
    const playerCheckboxes = Array.from(
      document.querySelectorAll('input[name="match_day[player_ids][]"]'),
    );
    playerCheckboxes.forEach((checkbox) => {
      checkbox.addEventListener("change", () => this.render());
    });

    [
      this.poolTarget,
      this.teamATarget,
      this.teamBTarget,
      this.teamWaitingTarget,
    ].forEach((list) => {
      list.addEventListener("dragover", (event) => {
        event.preventDefault();
        list.classList.add("lineup-column__list--dragover");
      });

      list.addEventListener("dragleave", () => {
        list.classList.remove("lineup-column__list--dragover");
      });

      list.addEventListener("drop", (event) => {
        event.preventDefault();
        list.classList.remove("lineup-column__list--dragover");
        const playerId = event.dataTransfer.getData("text/plain");
        this.movePlayer(playerId, list.dataset.lineupList);
      });
    });

    // Initial render
    this.render();
  }

  selectedPlayers() {
    const playerCheckboxes = Array.from(
      document.querySelectorAll('input[name="match_day[player_ids][]"]'),
    );
    return playerCheckboxes
      .filter((checkbox) => checkbox.checked)
      .map((checkbox) => ({
        id: checkbox.value,
        label:
          checkbox
            .closest("label")
            ?.querySelector("span")
            ?.textContent?.trim() || checkbox.value,
      }));
  }

  normalizeState() {
    const selectedIds = this.selectedPlayers().map((player) => player.id);

    this.state.teamA = this.state.teamA.filter((id) => selectedIds.includes(id));
    this.state.teamB = this.state.teamB.filter(
      (id) => selectedIds.includes(id) && !this.state.teamA.includes(id),
    );
    this.state.teamWaiting = this.state.teamWaiting.filter(
      (id) =>
        selectedIds.includes(id) &&
        !this.state.teamA.includes(id) &&
        !this.state.teamB.includes(id),
    );
  }

  createCard(player, column) {
    const card = document.createElement("button");
    card.type = "button";
    card.className = "lineup-card";
    card.draggable = true;
    card.dataset.playerId = player.id;
    card.dataset.sourceColumn = column;
    card.textContent = player.label;

    // Add drag event listeners
    card.addEventListener("dragstart", (event) => {
      event.dataTransfer.setData("text/plain", player.id);
      event.dataTransfer.setData("application/x-lineup-source", column);
    });

    // Add click-to-swap functionality
    card.addEventListener("click", (event) => {
      event.stopPropagation();
      // Allow circular swapping: Team A -> Team B -> Team 3 -> Team A
      let targetColumn;
      if (column === "team_a") targetColumn = "team_b";
      else if (column === "team_b") targetColumn = "team_waiting";
      else if (column === "team_waiting") targetColumn = "team_a";

      if (targetColumn) {
        this.movePlayer(player.id, targetColumn);
      }
    });

    return card;
  }

  renderInputs(container, name, ids) {
    container.replaceChildren();

    ids.forEach((id) => {
      const input = document.createElement("input");
      input.type = "hidden";
      input.name = name;
      input.value = id;
      container.appendChild(input);
    });
  }

  render() {
    this.normalizeState();

    const players = this.selectedPlayers();
    const assignedIds = new Set([
      ...this.state.teamA,
      ...this.state.teamB,
      ...this.state.teamWaiting,
    ]);
    const poolPlayers = players.filter((player) => !assignedIds.has(player.id));
    const teamAPlayers = players.filter((player) =>
      this.state.teamA.includes(player.id),
    );
    const teamBPlayers = players.filter((player) =>
      this.state.teamB.includes(player.id),
    );
    const teamWaitingPlayers = players.filter((player) =>
      this.state.teamWaiting.includes(player.id),
    );

    this.poolTarget.replaceChildren(
      ...poolPlayers.map((player) => this.createCard(player, "pool")),
    );
    this.teamATarget.replaceChildren(
      ...teamAPlayers.map((player) => this.createCard(player, "team_a")),
    );
    this.teamBTarget.replaceChildren(
      ...teamBPlayers.map((player) => this.createCard(player, "team_b")),
    );
    this.teamWaitingTarget.replaceChildren(
      ...teamWaitingPlayers.map((player) =>
        this.createCard(player, "team_waiting"),
      ),
    );

    this.renderInputs(
      this.teamAInputsTarget,
      "match_day[team_a_player_ids][]",
      this.state.teamA,
    );
    this.renderInputs(
      this.teamBInputsTarget,
      "match_day[team_b_player_ids][]",
      this.state.teamB,
    );
    this.renderInputs(
      this.teamWaitingInputsTarget,
      "match_day[team_waiting_player_ids][]",
      this.state.teamWaiting,
    );
  }

  movePlayer(playerId, targetColumn) {
    this.state.teamA = this.state.teamA.filter((id) => id !== playerId);
    this.state.teamB = this.state.teamB.filter((id) => id !== playerId);
    this.state.teamWaiting = this.state.teamWaiting.filter(
      (id) => id !== playerId,
    );

    if (targetColumn === "team_a") this.state.teamA.push(playerId);
    if (targetColumn === "team_b") this.state.teamB.push(playerId);
    if (targetColumn === "team_waiting") this.state.teamWaiting.push(playerId);

    this.render();
  }
}
