import { readFile } from 'node:fs/promises';
import { before, after, beforeEach, test } from 'node:test';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { doc, setDoc, getDoc, getDocs, collection, writeBatch, updateDoc } from 'firebase/firestore';

let env;
const projectId = 'demo-dompetku';
const now = Date.now();
const wallet = { id: 1, name: 'Tunai', type: 'cash', initialBalance: 10000,
  isArchived: false, createdAt: now, updatedAt: now };
const path = (uid, name = 'wallets', id = 1, dataset = 'initial') =>
  `users/${uid}/datasets/${dataset}/${name}/${id}`;

before(async () => {
  env = await initializeTestEnvironment({projectId, firestore: {
    host: '127.0.0.1', port: 8080,
    rules: await readFile(new URL('../../firestore.rules', import.meta.url), 'utf8'),
  }});
});
beforeEach(() => env.clearFirestore());
after(async () => env?.cleanup());

test('owner can create, list and read their own data', async () => {
  const db = env.authenticatedContext('alice').firestore();
  await assertSucceeds(setDoc(doc(db,path('alice')), wallet));
  await assertSucceeds(getDoc(doc(db,path('alice'))));
  await assertSucceeds(getDocs(collection(db,'users/alice/datasets/initial/wallets')));
});

test('anonymous and another account cannot read or write any generation', async () => {
  const alice = env.authenticatedContext('alice').firestore();
  await setDoc(doc(alice,path('alice')), wallet);
  for (const db of [env.unauthenticatedContext().firestore(), env.authenticatedContext('bob').firestore()]) {
    await assertFails(getDoc(doc(db,path('alice'))));
    await assertFails(setDoc(doc(db,path('alice')), wallet));
    await assertFails(getDocs(collection(db,'users/alice/datasets/initial/wallets')));
    await assertFails(setDoc(doc(db,path('alice','wallets',1,'staging')),wallet));
  }
});

test('rejects fractional Rupiah, unexpected fields, invalid IDs and types', async () => {
  const db = env.authenticatedContext('alice').firestore();
  for (const invalid of [
    {...wallet,initialBalance:1.5}, {...wallet,secret:'x'}, {...wallet,id:2},
    {...wallet,name:''}, {...wallet,type:'unknown'}, {...wallet,createdAt:'today'},
  ]) await assertFails(setDoc(doc(db,path('alice')), invalid));
  await assertFails(setDoc(doc(db,path('alice','unknown')),wallet));
});

test('valid transfer keeps source and destination distinct with integer amount', async () => {
  const db = env.authenticatedContext('alice').firestore();
  const transfer = {id:1,type:'transfer',amount:25000,categoryId:null,walletId:1,
    transferWalletId:2,date:now,note:null,createdAt:now,updatedAt:now};
  const ref=doc(db,path('alice','transactions'));
  await assertSucceeds(setDoc(ref,transfer));
  await assertFails(setDoc(ref,{...transfer,transferWalletId:1}));
  await assertFails(setDoc(ref,{...transfer,amount:25000.5}));
  await assertFails(setDoc(ref,{...transfer,categoryId:1}));
  await assertFails(setDoc(ref,{...transfer,type:'expense',transferWalletId:null,categoryId:null}));
});

test('validates budget and settings independently of client UI', async () => {
  const db=env.authenticatedContext('alice').firestore();
  const budget={id:1,categoryId:null,month:'2026-11',limitAmount:1000,createdAt:now,updatedAt:now};
  await assertSucceeds(setDoc(doc(db,path('alice','budgets')),budget));
  await assertFails(setDoc(doc(db,path('alice','budgets')),{...budget,month:'2026-13'}));
  const settings={id:1,userName:null,currency:'IDR',themeMode:'system',hideBalance:false,
    onboardingCompleted:false,monthlyResetDay:1,createdAt:now,updatedAt:now};
  await assertSucceeds(setDoc(doc(db,path('alice','settings')),settings));
  await assertFails(setDoc(doc(db,path('alice','settings')),{...settings,monthlyResetDay:32}));
  await assertFails(setDoc(doc(db,path('alice','settings')),{...settings,currency:'USD'}));
});

test('staged import can switch pointer and cannot erase migration marker', async () => {
  const db=env.authenticatedContext('alice').firestore();
  const ref=doc(db,'users/alice');
  await assertSucceeds(setDoc(ref,{schemaVersion:1,activeDataset:'initial',createdAt:now,legacyMigration:null}));
  const batch=writeBatch(db);
  batch.set(doc(db,path('alice','wallets',1,'imported')),wallet);
  batch.update(ref,{activeDataset:'imported',legacyMigration:'a'.repeat(64)});
  await assertSucceeds(batch.commit());
  await assertFails(updateDoc(ref,{legacyMigration:null}));
  await assertFails(getDocs(collection(db,'users')));
});

const bill = {id:1,title:'Internet',amount:250000,categoryId:1,walletId:1,
  nextDueDate:now,frequency:'monthly',anchorDay:31,isActive:true,createdAt:now,updatedAt:now};
const goal = {id:1,name:'Dana darurat',targetAmount:10000000,savedAmount:250000,
  targetDate:null,createdAt:now,updatedAt:now};

test('planning collections enforce owner isolation on reads and writes', async () => {
  const alice=env.authenticatedContext('alice').firestore();
  for (const [name,row] of [['recurring_bills',bill],['savings_goals',goal]]) {
    await assertSucceeds(setDoc(doc(alice,path('alice',name)),row));
    await assertSucceeds(getDocs(collection(alice,`users/alice/datasets/initial/${name}`)));
    for (const db of [env.unauthenticatedContext().firestore(),env.authenticatedContext('bob').firestore()]) {
      await assertFails(getDoc(doc(db,path('alice',name))));
      await assertFails(setDoc(doc(db,path('alice',name)),row));
      await assertFails(getDocs(collection(db,`users/alice/datasets/initial/${name}`)));
    }
  }
});

test('recurring bills reject invalid recurrence, amount and references', async () => {
  const db=env.authenticatedContext('alice').firestore();
  const ref=doc(db,path('alice','recurring_bills'));
  for (const invalid of [
    {...bill,title:''},{...bill,amount:0},{...bill,amount:1.5},
    {...bill,frequency:'daily'},{...bill,anchorDay:0},{...bill,anchorDay:32},
    {...bill,categoryId:null},{...bill,walletId:-1},{...bill,isActive:'true'},
    {...bill,nextDueDate:'today'},{...bill,secret:'unexpected'},
  ]) await assertFails(setDoc(ref,invalid));
  for (const frequency of ['weekly','monthly','yearly']) {
    await assertSucceeds(setDoc(ref,{...bill,frequency}));
  }
});

test('savings goals accept progress beyond target but reject invalid money', async () => {
  const db=env.authenticatedContext('alice').firestore();
  const ref=doc(db,path('alice','savings_goals'));
  await assertSucceeds(setDoc(ref,{...goal,savedAmount:11000000,targetDate:now}));
  for (const invalid of [
    {...goal,name:''},{...goal,targetAmount:0},{...goal,savedAmount:-1},
    {...goal,savedAmount:1.5},{...goal,targetDate:'tomorrow'},{...goal,pin:'1234'},
  ]) await assertFails(setDoc(ref,invalid));
});
