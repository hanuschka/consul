// Final-import progress bar. The status endpoint reports the job's current
// submit_stage, and the bar sits at that stage's position with its label.
// "queued" is the gap between the import request and the job picking it up.
// A stage the import never reaches — a copied projekt, a title image taken
// from the document rather than generated — is never reported, so it is
// never shown. The bar snaps to 100% on completion.
const SUBMIT_STAGE_PERCENTS = {
  queued: 5,
  creating_projekt: 20,
  resolving_content_blocks: 45,
  creating_content_blocks: 65,
  generating_image: 85,
  copying_projekt: 50
}

export default SUBMIT_STAGE_PERCENTS
