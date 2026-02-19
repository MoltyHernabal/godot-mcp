import { z } from 'zod';
import { defineTool } from '../core/define-tool.js';

const AtomicFindGetSchema = z.object({
  root_path: z.string().optional().describe('Root path to search from'),
  name_pattern: z.string().describe('Node name pattern to match')
});

type AtomicFindGetArgs = z.infer<typeof AtomicFindGetSchema>;

export const atomic_find_and_get = defineTool({
  name: 'atomic_find_and_get',
  description: 'Atomically find nodes and get their properties (prevents split-state during scene tree changes)',
  schema: AtomicFindGetSchema,
  async execute(args: AtomicFindGetArgs, { godot }) {
    const result = await godot.sendCommand<{
      find: any;
      get: any;
    }>('atomic_find_and_get', {
      root_path: args.root_path || '',
      name_pattern: args.name_pattern
    });
    return JSON.stringify(result, null, 2);
  }
});

const AtomicUpdateSchema = z.object({
  node_path: z.string().describe('Node path to update'),
  properties: z.record(z.string(), z.any()).describe('Properties to set')
});

type AtomicUpdateArgs = z.infer<typeof AtomicUpdateSchema>;

export const atomic_update_and_get = defineTool({
  name: 'atomic_update_and_get',
  description: 'Atomically update node and get its new properties (prevents split-state)',
  schema: AtomicUpdateSchema,
  async execute(args: AtomicUpdateArgs, { godot }) {
    const result = await godot.sendCommand<{
      before: any;
      after: any;
    }>('atomic_update_and_get', {
      node_path: args.node_path,
      properties: args.properties
    });
    return JSON.stringify(result, null, 2);
  }
});

export const atomicTools = [
  atomic_find_and_get,
  atomic_update_and_get
] as any;
