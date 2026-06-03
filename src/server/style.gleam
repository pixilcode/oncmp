pub const styles = "
  /* reset */
  h1,
  h2,
  p,
  ul,
  li,
  pre {
    margin: 0;
    padding: 0;
  }

  :root {
    --bkg-purple: #fcf9ff;
    --txt-purple: #26013f;
    --border-purple: #dccee5;

    --bkg-red: #ffe5e5;
    --txt-red: #990f0f;

    --bkg-green: #e5ffe5;
    --txt-green: #0a660a;
  }

  * {
    font-family: 'Fira Mono', mono;
  }

  body {
    background-color: var(--bkg-purple);
    color: var(--txt-purple);

    padding: 1rem;

    display: grid;
    justify-content: center;
  }

  h1,
  h2 {
    font-weight: 700;
  }

  h1,
  main {
    border: 2px solid var(--border-purple);
    padding: 1rem 2rem;
  }

  h1 {
    border-radius: 1rem 1rem 0 0;
  }

  main {
    border-top-width: 0px;
    border-radius: 0 0 1rem 1rem;
  }

  pre {
    font-weight: 400;
  }

  section {
    padding: 1rem 0;
  }

  .controls {
    display: flex;
    flex-direction: row;
    justify-content: center;
    gap: 2rem;
  }

  .diff-list {
    display: grid;
    grid-template-columns: 1.5rem auto;
    grid-row-gap: 0.5rem;
    margin: 1rem 0;
  }

  .diff {
    grid-column: span 2;

    list-style: none;
    border-radius: 0.5rem;
    overflow: clip;
    display: grid;
    grid-template-columns: subgrid;
  }

  .diff.unchanged {
    display: none;
  }

  .add {
    background-color: var(--bkg-green);
    color: var(--txt-green);
  }

  .remove {
    background-color: var(--bkg-red);
    color: var(--txt-red);
  }

  .diff .indicator,
  .diff .content {
    padding-top: 0.25rem;
    padding-bottom: 0.25rem;
  }

  .diff .indicator {
    grid-column: 1;
    text-align: center;
  }

  .diff .content {
    grid-column: 2;
    padding-right: 0.5rem;
  }

  .summary {
    font-weight: 500;
  }

  .error {
    color: var(--txt-red);
    background-color: var(--bkg-red);
    padding: 1rem;
    border-radius: 0.5rem;

    display: flex;
    flex-direction: column;
    gap: 2rem;
  }

  .error .source {
    padding: 0 1rem;
  }

  /* controls */

  main:has(#show-parameters-input:not(:checked)) .params {
    display: none;
  }

  main:has(#show-tests-input:not(:checked)) .tests {
    display: none;
  }

  main:has(#show-unchanged-input:checked) .diff.unchanged {
    display: grid;
  }

  main:has(#show-source-input:not(checked)) .error .source {
    display: none;
  }
  "
