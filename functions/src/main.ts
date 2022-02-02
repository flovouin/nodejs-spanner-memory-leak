import { SessionPool, Spanner } from '@google-cloud/spanner';

const spanner = new Spanner();
let database = spanner
  .instance(process.env.SPANNER_INSTANCE)
  .database(process.env.SPANNER_DATABASE);

const TABLE_NAME = 'myEntity';

/**
 * Single read without transaction.
 */
export const readNoTransaction = async (): Promise<void> => {
  const number = Math.round(Math.random() * 10000);
  const id = number.toString();

  const [response] = await database.table(TABLE_NAME).read({
    columns: ['id', 'value'],
    keys: [id],
  });
  if (response.length > 0) {
    console.log(`Found ${id}!`);
  } else {
    console.log(`Did not find ${id}!`);
  }
};

/**
 * Single upsert without transaction.
 */
export const upsertNoTransaction = async (): Promise<void> => {
  const number = Math.round(Math.random() * 10000);
  const id = number.toString();
  const myObject = { id, value: number };

  await database.table(TABLE_NAME).upsert(myObject);
  console.log(`Upserted ${id}!`);
};

/**
 * Single read in transaction.
 */
export const readInTransaction = async (): Promise<void> => {
  const number = Math.round(Math.random() * 10000);
  const id = number.toString();

  await database.runTransactionAsync(async (transaction) => {
    const [response] = await transaction.read(TABLE_NAME, {
      columns: ['id', 'value'],
      keys: [id],
    });
    if (response.length > 0) {
      console.log(`Found ${id}!`);
    } else {
      console.log(`Did not find ${id}!`);
    }

    await transaction.commit();
  });

  const pool: SessionPool = database.pool_ as any;
  console.log({
    msg: 'session stats',
    traceSize: pool._traces.size,
    borrowedSize: pool._inventory.borrowed.size,
    readOnlySize: pool._inventory.readonly.length,
    readWriteSize: pool._inventory.readwrite.length,
  });
};

/**
 * Single upsert in transaction.
 */
export const upsertInTransaction = async (): Promise<void> => {
  const number = Math.round(Math.random() * 10000);
  const id = number.toString();

  await database.runTransactionAsync(async (transaction) => {
    transaction.upsert(TABLE_NAME, { id, value: number });
    await transaction.commit();
  });
  console.log(`Upserted ${id}!`);
};

/**
 * Single SQL read in transaction.
 */
export const sqlInTransaction = async (): Promise<void> => {
  const number = Math.round(Math.random() * 10000);
  const id = number.toString();

  await database.runTransactionAsync(async (transaction) => {
    const [response] = await transaction.run({
      sql: `SELECT id, value FROM ${TABLE_NAME} WHERE id = '${id}'`,
    });

    if (response.length > 0) {
      console.log(`Found ${id}!`);
    } else {
      console.log(`Did not find ${id}!`);
    }

    await transaction.commit();
  });
};

/**
 * Single read in a snapshot.
 */
export const readInSnapshot = async (): Promise<void> => {
  const number = Math.round(Math.random() * 10000);
  const id = number.toString();

  const [snapshot] = await database.getSnapshot();
  const [response] = await snapshot.read(TABLE_NAME, {
    columns: ['id', 'value'],
    keys: [id],
  });

  if (response.length > 0) {
    console.log(`Found ${id}!`);
  } else {
    console.log(`Did not find ${id}!`);
  }

  snapshot.end();
};

/**
 * NOP in transaction.
 */
export const nopInTransaction = async (): Promise<void> => {
  await database.runTransactionAsync(async (transaction) => {
    await transaction.commit();
  });
};

/**
 * NOP in rolled back transaction.
 */
export const nopInRolledBackTransaction = async (): Promise<void> => {
  await database.runTransactionAsync(async (transaction) => {
    await transaction.rollback();
  });
};

/**
 * NOP in ended transaction.
 */
export const nopInEndedTransaction = async (): Promise<void> => {
  await database.runTransactionAsync(async (transaction) => {
    transaction.end();
  });
};

/**
 * Close the database, sometimes.
 */
export const closeTransaction = async (): Promise<void> => {
  if (Math.random() < 0.01) {
    console.log('Closing database...');

    await database.close();
    database = spanner
      .instance(process.env.SPANNER_INSTANCE)
      .database(process.env.SPANNER_DATABASE);
  }

  await database.runTransactionAsync(async (transaction) => {
    await transaction.commit();
  });
};
