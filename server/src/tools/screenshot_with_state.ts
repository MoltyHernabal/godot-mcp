import { z } from 'zod';
import { defineTool } from '../core/define-tool.js';

// Screenshot with state capture
const ScreenshotWithStateSchema = z.object({
  max_width: z.number().optional().describe('Maximum width of screenshot (default: 1920)'),
  include_telemetry: z.boolean().optional().describe('Include telemetry counters and events (default: true)'),
  include_scene_tree: z.boolean().optional().describe('Include current scene tree state (default: true)')
});

export const screenshot_with_state = defineTool({
  name: 'screenshot_with_state',
  description: 'Capture screenshot with complete game state snapshot (player, enemy, camera, UI states, telemetry events, scene tree)',
  schema: ScreenshotWithStateSchema,
  async execute(args, { godot }) {
    const result = await godot.sendCommand('take_screenshot_with_state', {
      max_width: args.max_width || 1920,
      include_telemetry: args.include_telemetry !== false,
      include_scene_tree: args.include_scene_tree !== false
    });

    return {
      screenshot: result.screenshot_path,
      timestamp: result.timestamp,
      physics_frame: result.physics_frame,
      process_frame: result.process_frame,
      state: result.state_snapshot,
      telemetry: result.include_telemetry ? result.telemetry_snapshot : undefined,
      scene_tree: result.include_scene_tree ? result.scene_tree_snapshot : undefined
    };
  }
});

export const screenshotWithStateTools = [
  screenshot_with_state
];
