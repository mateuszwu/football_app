import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["pool", "teamA", "teamB", "teamAInputs", "teamBInputs"];
  static values = {
    teamAPlayerIds: Array,
    teamBPlayerIds: Array,
  };

  connect() {
    if (this.element.dataset.lineupInitialized === "true") return;

    this.element.dataset.lineupInitialized = "true";

    // Initialize state from dataset
    this.state = {
      teamA: (this.teamAPlayerIdsValue || []).map(String),
      teamB: (this.teamBPlayerIdsValue || []).map(String),
    };

    // Setup listeners for checkbox changes
    const playerCheckboxes = Array.from(
      document.querySelectorAll('input[name="match_day[player_ids][]"]'),
    );
    playerCheckboxes.forEach((checkbox) => {
      checkbox.addEventListener("change", () => this.render());
    });

    [this.poolTarget, this.teamATarget, this.teamBTarget].forEach((list) => {
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

    this.state.teamA = this.state.teamA.filter((id) =>
      selectedIds.includes(id),
    );
    this.state.teamB = this.state.teamB.filter(
      (id) => selectedIds.includes(id) && !this.state.teamA.includes(id),
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
      // Only allow swapping between Team A and Team B
      if (column === "team_a" || column === "team_b") {
        const targetColumn = column === "team_a" ? "team_b" : "team_a";

        // Find and swap the player by moving to target column
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
    const assignedIds = new Set([...this.state.teamA, ...this.state.teamB]);
    const poolPlayers = players.filter((player) => !assignedIds.has(player.id));
    const teamAPlayers = players.filter((player) =>
      this.state.teamA.includes(player.id),
    );
    const teamBPlayers = players.filter((player) =>
      this.state.teamB.includes(player.id),
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
  }

  movePlayer(playerId, targetColumn) {
    this.state.teamA = this.state.teamA.filter((id) => id !== playerId);
    this.state.teamB = this.state.teamB.filter((id) => id !== playerId);

    if (targetColumn === "team_a") this.state.teamA.push(playerId);
    if (targetColumn === "team_b") this.state.teamB.push(playerId);

    this.render();
  }
}
