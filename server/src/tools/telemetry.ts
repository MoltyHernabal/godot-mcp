import { z } from 'zod';
import { defineTool } from '../core/define-tool.js';
import type { AnyToolDefinition } from '../core/types.js';

// Get counters
const GetCountersSchema = z.object({
  source: z.string().optional().describe('Source to get counters for (optional, returns all if empty)')
});

type GetCountersArgs = z.infer<typeof GetCountersSchema>;

export const get_counters = defineTool({
  name: 'get_counters',
  description: 'Get deterministic hit/miss/consume/evade counters for collision detection',
  schema: GetCountersSchema,
  async execute(args: GetCountersArgs, { godot }) {
    const result = await godot.sendCommand<{
      counters: Record<string, unknown>;
    }>('get_counters', {
      source: args.source || ''
    });
    return JSON.stringify(result.counters, null, 2);
  }
});

// Get events
const GetEventsSchema = z.object({
  limit: z.number().optional().describe('Number of recent events to return (default: 100)'),
  event_type: z.string().optional().describe('Filter by event type: hit, miss, consume, evade, collision_type')
});

type GetEventsArgs = z.infer<typeof GetEventsSchema>;

export const get_events = defineTool({
  name: 'get_events',
  description: 'Get recent event log for collision detection',
  schema: GetEventsSchema,
  async execute(args: GetEventsArgs, { godot }) {
    const result = await godot.sendCommand<{
      events: unknown[];
      count: number;
    }>('get_events', {
      limit: args.limit || 100,
      event_type: args.event_type || ''
    });
    return JSON.stringify(result.events, null, 2);
  }
});

// Clear events
const ClearEventsSchema = z.object({
  source: z.string().optional().describe('Source to clear events for (optional, clears all if empty)')
});

type ClearEventsArgs = z.infer<typeof ClearEventsSchema>;

export const clear_events = defineTool({
  name: 'clear_events',
  description: 'Clear event log for collision detection',
  schema: ClearEventsSchema,
  async execute(args: ClearEventsArgs, { godot }) {
    const result = await godot.sendCommand<{
      cleared: boolean;
      source: string;
    }>('clear_events', {
      source: args.source || ''
    });
    return `Cleared events for: ${result.source}`;
  }
});

// Clear counters
const ClearCountersSchema = z.object({
  source: z.string().optional().describe('Source to clear counters for (optional, clears all if empty)')
});

type ClearCountersArgs = z.infer<typeof ClearCountersSchema>;

export const clear_counters = defineTool({
  name: 'clear_counters',
  description: 'Clear all counters for collision detection',
  schema: ClearCountersSchema,
  async execute(args: ClearCountersArgs, { godot }) {
    const result = await godot.sendCommand<{
      cleared: boolean;
      source: string;
    }>('clear_counters', {
      source: args.source || ''
    });
    return `Cleared counters for: ${result.source}`;
  }
});

// Get stats summary
const GetStatsSummarySchema = z.object({});

type GetStatsSummaryArgs = z.infer<typeof GetStatsSummarySchema>;

export const get_stats_summary = defineTool({
  name: 'get_stats_summary',
  description: 'Get comprehensive statistics summary (total hits, miss rate, hit rate, etc.)',
  schema: GetStatsSummarySchema,
  async execute(args: GetStatsSummaryArgs, { godot }) {
    const result = await godot.sendCommand<{
      summary: Record<string, unknown>;
    }>('get_stats_summary', {});
    return JSON.stringify(result.summary, null, 2);
  }
});

export const telemetryTools = [
  get_counters,
  get_events,
  clear_events,
  clear_counters,
  get_stats_summary
] as any;
