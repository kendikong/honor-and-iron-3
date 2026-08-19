import { Callout, H1, H2, Stack, Stat, Table, Text } from "cursor/canvas";

type Scenario = {
  id: string;
  setup: string;
  owner: string;
};

type AtomicRow = {
  id: string;
  scenario: string;
  checkpoint: string;
  dimension: string;
  owner: string;
  status: "CHECKLIST — required";
};

const checkpoints = [
  "setup",
  "select-unit",
  "select-ability",
  "initial-hover",
  "route-begin",
  "route-progress",
  "route-final",
  "enemy-transition",
  "target-settled",
  "snapshot-captured",
  "pre-click",
  "click-ratified",
  "timeline-written",
  "post-commit",
  "sim-resolution",
  "final-parity",
  "replan-from-stand",
];

const dimensions = [
  "hover-cell", "selected-unit", "route-cells", "waypoints", "route-leg",
  "approach-origin", "latest-stand", "projected-board", "facing",
  "target-coord", "target-unit", "ability-id", "authored-ability",
  "module-coords", "module-units", "affected-tiles", "forecast-damage",
  "forecast-status", "terrain-forecast", "ap-before", "mp-before",
  "ap-after", "mp-after", "legality", "blue-tiles", "red-tiles", "arrows",
  "cursor", "unit-ghost-position", "unit-ghost-facing",
  "timeline-ghost-visible", "timeline-ghost-metadata", "snapshot-identity",
  "slot-signature", "sim-result", "movement-events", "displacement-events",
  "execution-economy", "execution-effects", "execution-parity",
];

const scenarios: Scenario[] = [
  ["PS-R1", "Archer (2,2)→(2,3)→(3,3)→(3,4)→(4,4), enemy (7,4).", "tests/planning_qa_gate_test.gd::_test_waypoint_premove_enemy_hover_full_truth"],
  ["PS-R2", "Archer (8,8)→(8,7)→(7,7)→(7,6)→(6,6), enemy (2,6).", "tests/planning_qa_gate_test.gd::_test_waypoint_premove_enemy_hover_full_truth"],
  ["PS-R3", "Archer (2,8)→(3,8)→(3,7)→(4,7)→(4,6), enemy (8,6).", "tests/planning_qa_gate_test.gd::_test_waypoint_premove_enemy_hover_full_truth"],
  ["VO-R1", "Archer sideflank route 1, enemy (7,4), tile AOE.", "tests/planning_qa_gate_test.gd::_test_waypoint_premove_then_tile_aoe_enemy_hover"],
  ["VO-R2", "Archer sideflank route 2, enemy (2,6), tile AOE.", "tests/planning_qa_gate_test.gd::_test_waypoint_premove_then_tile_aoe_enemy_hover"],
  ["VO-R3", "Archer sideflank route 3, enemy (8,6), tile AOE.", "tests/planning_qa_gate_test.gd::_test_waypoint_premove_then_tile_aoe_enemy_hover"],
  ["SS-E1", "Sidestep after exhausted full-MP premove, enemy hover rejected.", "tests/planning_qa_gate_test.gd::_test_sidestep_enemy_click_ratifies_move_preview"],
  ["SS-E2", "Sidestep exhausted route 2, enemy hover rejected.", "tests/planning_qa_gate_test.gd::_test_sidestep_enemy_click_ratifies_move_preview"],
  ["SS-E3", "Sidestep exhausted route 3, enemy hover rejected.", "tests/planning_qa_gate_test.gd::_test_sidestep_enemy_click_ratifies_move_preview"],
  ["SS-V1", "Sidestep valid short premove and tile target.", "tests/planning_qa_gate_test.gd::_test_sidestep_valid_tile_after_waypoint_premove"],
  ["SS-V2", "Sidestep valid two-waypoint premove and tile target.", "tests/planning_qa_gate_test.gd::_test_sidestep_valid_tile_after_waypoint_premove"],
  ["PS-R-INVALID", "Power Shot remains out of range after full-MP route.", "tests/planning_qa_gate_test.gd::_test_out_of_range_hover_is_invalid"],
  ["WALK-01", "Knight walk to adjacent empty cell.", "tests/planning_qa_gate_test.gd::_test_committed_walk_preview_matches_sim_path"],
  ["MOVE-SKILL-01", "Knight approach into Shield Bash.", "tests/planning_qa_gate_test.gd::_test_shield_bash_full_approach_push_preview"],
  ["PUSH-PULL-01", "Chain Hook displacement and Shield Bash push.", "tests/intent_source_of_truth_gate_test.gd::_test_push_pull_01"],
  ["SWAP-01", "Dependent premove and ally swap.", "tests/intent_source_of_truth_gate_test.gd::_test_swap_01"],
  ["AWAIT-01", "Far awaiting target rejected, valid target accepted.", "tests/intent_source_of_truth_gate_test.gd::_test_await_01"],
  ["TRAMPLE-01", "Trampling Advance east-then-north action corridor.", "tests/planning_qa_gate_test.gd::_test_trample_full_preview_truth_click"],
  ["TRAMPLE-REPATH-01", "Pathfinder repath cannot replace painted Trample order.", "tests/planning_qa_gate_test.gd::_test_trample_repath_does_not_replace_painted_order"],
  ["BASH-POST-01", "Shield Bash action end becomes POST move origin.", "tests/planning_qa_gate_test.gd::_test_move_preview_origin_premove_and_postmove"],
  ["TRAMPLE-POST-01", "Trample painted route followed by POST continuation.", "tests/planning_qa_gate_test.gd::_test_trample_post_move_preview_commit_sim"],
  ["RUN-WAIT-01", "Run economy boundary followed by Wait.", "tests/planning_qa_gate_test.gd::_test_cursor_walk_run_and_composite"],
  ["DRAG-DROP-01", "Click/drop movement route parity.", "tests/planning_qa_gate_test.gd::_test_click_drop_drag_walk_sim_parity"],
  ["TELEPORT-01", "Teleport landing and latest-stand replan.", "tests/planning_qa_gate_test.gd::_test_teleport_full_preview_truth_click"],
  ["I-T01-01", "Mid-route waypoint change.", "tests/planning_qa_gate_test.gd::_test_stale_hover_updates_commit_waypoints"],
  ["I-T02-01", "Final waypoint transition to enemy.", "tests/planning_qa_gate_test.gd::_test_waypoint_premove_enemy_hover_full_truth"],
  ["I-T03-01", "Enemy hover leaves to empty tile.", "tests/planning_qa_gate_test.gd::_test_shield_bash_hover_change_clears_stale_approach"],
  ["I-T04-01", "Ability switch Power Shot to Volley.", "tests/planning_qa_gate_test.gd::_test_ability_switch_clears_preview_cache"],
  ["I-T05-01", "Re-arm from latest stand.", "tests/planning_qa_gate_test.gd::_test_action_range_centered_on_live_stand"],
  ["I-T06-01", "Drag cancel and right-click.", "tests/planning_qa_gate_test.gd::_test_drag_cleared_restores_canonical_bash_intent"],
  ["I-T07-01", "Undo removes dependent action.", "tests/planning_qa_gate_test.gd::_test_drag_drop_commit_undo_clears_plan"],
  ["I-T08-01", "Enemy A to enemy B target switch.", "tests/planning_qa_gate_test.gd::_test_hover_order_invariant"],
  ["I-T09-01", "Invalid hover then former target click.", "tests/planning_qa_gate_test.gd::_test_click_drop_parity_oob_invalid"],
  ["I-T10-01", "Post-commit re-hover.", "tests/planning_qa_gate_test.gd::_test_timeline_ghost_clears_when_committed"],
  ["N-OOB-01", "Out-of-bounds waypoint rejected.", "tests/planning_qa_gate_test.gd::_test_click_drop_parity_oob_invalid"],
  ["N-OCCUPIED-01", "Occupied endpoint rejected.", "tests/planning_qa_gate_test.gd::_test_invalid_slots_block_commit"],
  ["N-RANGE-01", "Out-of-range alias of PS-R-INVALID.", "tests/planning_qa_gate_test.gd::_test_out_of_range_hover_is_invalid"],
  ["N-AWAIT-FAR-01", "Awaiting far target rejected.", "tests/intent_source_of_truth_gate_test.gd::_test_await_01"],
  ["N-VOLLEY-TILE-01", "Illegal Volley tile rejected.", "tests/planning_qa_gate_test.gd::_test_tile_targeting_forbids_premove"],
  ["N-SILENCE-01", "Blocked AP/MP/state rejects action.", "tests/planning_qa_gate_test.gd::_test_invalid_slots_block_commit"],
  ["N-SNAPSHOT-01", "Stale snapshot cannot commit former intent.", "tests/planning_qa_gate_test.gd::_test_ability_switch_clears_preview_cache"],
].map((row) => ({ id: row[0], setup: row[1], owner: row[2] }));

const scenarioFacts = Object.fromEntries(
  scenarios.map((scenario) => [
    scenario.id,
    {
      setup: scenario.setup,
      owner: scenario.owner,
      legality: scenario.id.startsWith("N-") ? "invalid-path-required" : "valid-path-required",
    },
  ]),
);

const atomicRows: AtomicRow[] = scenarios.flatMap((scenario) =>
  checkpoints.flatMap((checkpoint) =>
    dimensions.map((dimension) => ({
      id: `${scenario.id}::${checkpoint}::${dimension}`,
      scenario: scenario.id,
      checkpoint,
      dimension,
      owner: scenario.owner,
      status: "CHECKLIST — required" as const,
    })),
  ),
);

export default function PlanningPreviewTruthMatrix() {
  const total = atomicRows.length;
  const executableAtomicRows = atomicRows.filter(
    (row) => row.status !== "CHECKLIST — required",
  ).length;
  return (
    <Stack gap={16}>
      <H1>Planning Preview Truth Matrix</H1>
      <Callout tone="warning">
        Atomic rows are requirements until their concrete owner executes every applicable checkpoint and dimension.
      </Callout>
      <Stack direction="row" gap={12}>
        <Stat label="Scenarios" value={scenarios.length} />
        <Stat label="Checkpoints" value={checkpoints.length} />
        <Stat label="Dimensions" value={dimensions.length} />
        <Stat label="Required rows" value={total.toLocaleString()} />
        <Stat label="Scenario facts" value={Object.keys(scenarioFacts).length} />
        <Stat label="Executable atomic rows" value={executableAtomicRows} />
      </Stack>
      <Text>
        The acceptance invariant is preview → finalized slots → click ratification → committed timeline → Simulator.
        No row permits a heuristic rewrite or a “close enough” final-state assertion.
      </Text>
      <H2>Scenario owner ledger</H2>
      <Table
        columns={[
          { key: "id", header: "Scenario" },
          { key: "setup", header: "Concrete fixture" },
          { key: "owner", header: "Executable owner / status" },
        ]}
        data={scenarios}
      />
      <H2>Atomic dimensions</H2>
      <Text>{dimensions.join(" · ")}</Text>
      <H2>Atomic checkpoints</H2>
      <Text>{checkpoints.join(" → ")}</Text>
      <Text>
        Every row has an explicit ID in the form scenario::checkpoint::dimension.
        `scenarioFacts` supplies the concrete fixture owner and legality expectation;
        all rows remain CHECKLIST — required until their owner asserts that cell.
      </Text>
    </Stack>
  );
}
