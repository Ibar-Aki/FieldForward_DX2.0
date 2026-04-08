type CalcInput = {
  projectId?: string;
  machineType: string;
  loadCapacity: number;
  stopCount: number;
  travelHeight: number;
  worksheetName?: string;
  inputCells?: {
    machineType?: string;
    loadCapacity?: string;
    stopCount?: string;
    travelHeight?: string;
    projectId?: string;
  };
};

function main(workbook: ExcelScript.Workbook, input: CalcInput) {
  const worksheetName = input.worksheetName ?? "Calculator";
  const sheet = workbook.getWorksheet(worksheetName);
  if (!sheet) {
    throw new Error(`Worksheet '${worksheetName}' が見つかりません。`);
  }

  const inputCells = {
    machineType: "B2",
    loadCapacity: "B3",
    stopCount: "B4",
    travelHeight: "B5",
    projectId: "B6",
    ...input.inputCells
  };

  sheet.getRange(inputCells.machineType).setValue(input.machineType);
  sheet.getRange(inputCells.loadCapacity).setValue(input.loadCapacity);
  sheet.getRange(inputCells.stopCount).setValue(input.stopCount);
  sheet.getRange(inputCells.travelHeight).setValue(input.travelHeight);

  if (input.projectId) {
    sheet.getRange(inputCells.projectId).setValue(input.projectId);
  }

  workbook.getApplication().calculate(ExcelScript.CalculationType.full);

  return {
    worksheetName,
    calculationState: workbook.getApplication().getCalculationState(),
    timestamp: new Date().toISOString()
  };
}
