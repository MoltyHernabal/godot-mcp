import { z } from 'zod';
import { defineTool } from '../core/define-tool.js';

const SyncSchema = z.object({
  wait_for_physics: z.boolean().optional().describe('Wait for physics frame (default: true)'),
  wait_for_frames: z.number().optional().describe('Number of process frames to wait (default: 2)')
});

type SyncArgs = z.infer<typeof SyncSchema>;

export const synchronize = defineTool({
  name: 'synchronize',
  description: 'Synchronize MCP queries with game frame (aligns with physics/process frames for deterministic state)',
  schema: SyncSchema,
  async execute(args: SyncArgs, { godot }) {
    const result = await godot.sendCommand<{
      synced: boolean;
      physics_frame: number;
      process_frame: number;
      timestamp: number;
    }>('synchronize', {
      wait_for_physics: args.wait_for_physics ?? true,
      wait_for_frames: args.wait_for_frames ?? 2
    });
    return `Synchronized with game frame (physics: ${result.physics_frame}, process: ${result.process_frame})`;
  }
});

export const syncTools = [
  synchronize
] as any;
