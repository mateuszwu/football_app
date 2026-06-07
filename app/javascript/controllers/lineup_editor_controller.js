import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["pool", "columnsContainer"];
  static values = {
    teams: Array,
  };

  connect() {
    if (this.element.dataset.lineupInitialized === "true") return;
    this.element.dataset.lineupInitialized = "true";

    // Initialize state from values
    // teams: [{ name: "Team A", player_ids: ["1", "2"] }]
    this.state = {
      teams: (this.teamsValue || []).map((team) => ({
        name: team.name,
        player_ids: (team.player_ids || []).map(String),
      })),
    };

    // Setup listeners for checkbox changes
    const playerCheckboxes = Array.from(
      document.querySelectorAll('input[name="match_day[player_ids][]"]'),
    );
    playerCheckboxes.forEach((checkbox) => {
      checkbox.addEventListener("change", () => this.render());
    });

    // Setup pool listeners
    this.setupPoolListeners();

    // Initial render
    this.render();
  }

  addTeam(event) {
    event.preventDefault();
    const teamIndex = this.state.teams.length + 1;
    this.state.teams.push({
      name: `Team ${teamIndex}`,
      player_ids: [],
    });
    this.render();
  }

  removeTeam(event) {
    event.preventDefault();
    const index = parseInt(event.currentTarget.dataset.teamIndex);
    this.state.teams.splice(index, 1);
    this.render();
  }

  renameTeam(event) {
    const index = parseInt(event.currentTarget.dataset.teamIndex);
    this.state.teams[index].name = event.currentTarget.value;
    // We don't necessarily need to full render on every keystroke
    // but we need to update the hidden inputs or the name in state.
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

    // Filter out players that are no longer selected
    // and ensure players are not in multiple teams (preferring earlier teams)
    const allAssignedIds = new Set();
    this.state.teams.forEach((team) => {
      team.player_ids = team.player_ids.filter((id) => {
        if (selectedIds.includes(id) && !allAssignedIds.has(id)) {
          allAssignedIds.add(id);
          return true;
        }
        return false;
      });
    });
  }

  createCard(player, columnType, teamIndex = null) {
    const card = document.createElement("button");
    card.type = "button";
    card.className = "lineup-card";
    card.draggable = true;
    card.dataset.playerId = player.id;
    card.textContent = player.label;

    // Add drag event listeners
    card.addEventListener("dragstart", (event) => {
      event.dataTransfer.setData("text/plain", player.id);
    });

    // Add click-to-swap functionality
    card.addEventListener("click", (event) => {
      event.stopPropagation();
      this.handleCardClick(player.id, columnType, teamIndex);
    });

    return card;
  }

  handleCardClick(playerId, columnType, teamIndex) {
    let nextTeamIndex;

    if (columnType === "pool") {
      // From pool to first team
      nextTeamIndex = 0;
    } else {
      // From team to next team, or back to pool if last team
      nextTeamIndex = teamIndex + 1;
      if (nextTeamIndex >= this.state.teams.length) {
        nextTeamIndex = -1; // -1 means move back to pool
      }
    }

    this.movePlayer(playerId, nextTeamIndex);
  }

  render() {
    this.normalizeState();

    const players = this.selectedPlayers();
    const assignedIds = new Set(
      this.state.teams.flatMap((team) => team.player_ids),
    );
    const poolPlayers = players.filter((player) => !assignedIds.has(player.id));

    // Render Pool
    this.poolTarget.replaceChildren(
      ...poolPlayers.map((player) => this.createCard(player, "pool")),
    );

    // Render Dynamic Team Columns
    this.columnsContainerTarget.replaceChildren();

    this.state.teams.forEach((team, index) => {
      const column = this.createTeamColumn(team, index, players);
      this.columnsContainerTarget.appendChild(column);
    });
  }

  createTeamColumn(team, index, allPlayers) {
    const section = document.createElement("section");
    section.className = "lineup-column";
    section.dataset.teamIndex = index;

    const header = document.createElement("header");
    header.className = "lineup-column__header";

    const nameInput = document.createElement("input");
    nameInput.type = "text";
    nameInput.value = team.name;
    nameInput.className = "lineup-column__name-input";
    nameInput.name = `match_day[teams_data][${index}][name]`;
    nameInput.dataset.teamIndex = index;
    nameInput.dataset.action = "blur->lineup-editor#renameTeam";
    header.appendChild(nameInput);

    const removeBtn = document.createElement("button");
    removeBtn.type = "button";
    removeBtn.className = "button button--small button--danger";
    removeBtn.textContent = "×";
    removeBtn.dataset.teamIndex = index;
    removeBtn.dataset.action = "lineup-editor#removeTeam";
    header.appendChild(removeBtn);

    section.appendChild(header);

    const list = document.createElement("div");
    list.className = "lineup-column__list";
    list.dataset.teamIndex = index;

    const teamPlayers = allPlayers.filter((p) => team.player_ids.includes(p.id));
    list.replaceChildren(
      ...teamPlayers.map((p) => this.createCard(p, "team", index)),
    );

    // Drag and Drop listeners for the list
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
      this.movePlayer(playerId, index);
    });

    section.appendChild(list);

    // Hidden inputs for player IDs
    const inputsContainer = document.createElement("div");
    team.player_ids.forEach((id) => {
      const input = document.createElement("input");
      input.type = "hidden";
      input.name = `match_day[teams_data][${index}][player_ids][]`;
      input.value = id;
      inputsContainer.appendChild(input);
    });
    section.appendChild(inputsContainer);

    return section;
  }

  // Pool drag and drop
  setupPoolListeners() {
    this.poolTarget.addEventListener("dragover", (event) => {
      event.preventDefault();
      this.poolTarget.classList.add("lineup-column__list--dragover");
    });

    this.poolTarget.addEventListener("dragleave", () => {
      this.poolTarget.classList.remove("lineup-column__list--dragover");
    });

    this.poolTarget.addEventListener("drop", (event) => {
      event.preventDefault();
      this.poolTarget.classList.remove("lineup-column__list--dragover");
      const playerId = event.dataTransfer.getData("text/plain");
      this.movePlayer(playerId, -1);
    });
  }

  movePlayer(playerId, targetTeamIndex) {
    // Remove from all teams
    this.state.teams.forEach((team) => {
      team.player_ids = team.player_ids.filter((id) => id !== playerId);
    });

    // Add to target team if not moving to pool (-1)
    if (targetTeamIndex !== -1) {
      this.state.teams[targetTeamIndex].player_ids.push(playerId);
    }

    this.render();
  }
}
