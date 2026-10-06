import { readFileSync } from 'node:fs';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { dirname, extname, resolve } from 'node:path';
import { registerHooks, stripTypeScriptTypes } from 'node:module';

registerHooks({
  resolve(specifier, context, nextResolve) {
    if (!specifier.startsWith('.') || extname(specifier).length > 0 || context.parentURL === undefined) {
      return nextResolve(specifier, context);
    }
    const parentPath = fileURLToPath(context.parentURL);
    const candidatePath = resolve(dirname(parentPath), specifier + '.ets');
    try {
      readFileSync(candidatePath);
      return { url: pathToFileURL(candidatePath).href, shortCircuit: true };
    } catch {
      return nextResolve(specifier, context);
    }
  },
  load(url, context, nextLoad) {
    if (!url.endsWith('.ets')) {
      return nextLoad(url, context);
    }
    const source = readFileSync(fileURLToPath(url), 'utf8');
    return {
      format: 'module',
      source: stripTypeScriptTypes(source, { mode: 'transform' }),
      shortCircuit: true
    };
  }
});
