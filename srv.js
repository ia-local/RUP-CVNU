/**
 * serveir.js - Noyau de Diffusion "Braquage Fiscal"
 * Orchestration : Groq-SDK (Llama-3.1-8b-instant)
 * Logique : Souveraineté CVNU
 */
const express = require('express');
const fs = require('fs');

const app = express();

app.use(express.static('docs'));
app.use(express.json());

app.listen(3000, () => console.log('✅ JURIDICTION RUP-CVNU : SERVEUR ACTIF SUR PORT 3000'));