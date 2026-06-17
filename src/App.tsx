import { useEffect, useState } from "react";
import { generateClient } from "aws-amplify/data";
import type { Schema } from "../amplify/data/resource";

const client = generateClient<Schema>();

function App() {
  return (
    <div className="app">
      <h1>Amplify Gen2 Starter</h1>
      <p>Edit <code>amplify/data/resource.ts</code> to define your data models.</p>
      <p>Edit <code>src/App.tsx</code> to build your UI.</p>
    </div>
  );
}

export default App;
