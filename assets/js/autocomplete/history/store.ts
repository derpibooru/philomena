import store from '../../utils/store';
/**
 * The root JSON object that contains the history records and is persisted to disk.
 */
interface History {
  /**
   * Used to track the version of the schema layout just in case we do any
   * breaking changes to this schema so that we can properly migrate old
   * search history data. It's also used to prevent older versions of
   * the frontend code from trying to use the newer incompatible schema they
   * know nothing about (extremely improbable, but just in case).
   */
  schemaVersion: 1;

  /**
   * The list of history records sorted from the last recently used to the oldest unused.
   */
  records: string[];
}

/**
 * History store backend is responsible for parsing and serializing the data
 * to/from `localStorage`. It handles versioning of the schema, and transparently
 * disables writing to the storage if the schema version is unknown to prevent
 * data loss (extremely improbable, but just in case).
 */
export class HistoryStore {
  private writable: boolean = true;
  private readonly key: string;

  constructor(key: string) {
    this.key = key;
  }

  read(): string[] {
    return this.extractRecords(store.get<History>(this.key));
  }

  write(records: string[]): void {
    if (!this.writable) {
      return;
    }

    const history: History = {
      schemaVersion: 1,
      records,
    };

    const start = performance.now();
    store.set(this.key, history);

    const end = performance.now();
    console.debug(
      `Writing ${records.length} history records to the localStorage took ${end - start}ms. ` +
        `Records: ${records.length}`,
    );
  }

  /**
   * Extracts the records from the history. To do this, we first need to migrate
   * the history object to the latest schema version if necessary.
   */
  private extractRecords(history: History | null): string[] {
    // `null` here means we are starting from the initial state (empty list of records).
    if (history === null) {
      return [];
    }

    // We have only one version at the time of this writing, so we don't need
    // to do any migration yet. Hopefully we never need to do a breaking change
    // and this stays at version `1` forever.
    const latestSchemaVersion = 1;

    switch (history.schemaVersion) {
      case latestSchemaVersion:
        return history.records;
      default:
        // It's very unlikely that we ever hit this branch.
        console.warn(
          `Unknown search history schema version: '${history.schemaVersion}'. ` +
            `This frontend code was built with the maximum supported schema version ` +
            `'${latestSchemaVersion}'. The search history will be disabled for this ` +
            `session to prevent potential history data loss. The cause of the version ` +
            `mismatch may be that a newer version of the frontend code is running in a ` +
            `separate tab, or you were mistakenly served with an older version of the ` +
            `frontend code.`,
        );

        // Disallow writing to the storage to prevent data loss.
        this.writable = false;

        return [];
    }
  }
}
