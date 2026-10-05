@Component
export struct CycleStartDaySelector {
  @Prop startDay: number = 15;
  onChange: (day: number) => void = (_day: number) => {};

  build() {
    Button('每月' + this.startDay + '号')
      .backgroundColor('#E9F1FF')
      .fontColor('#2457C5')
      .onClick(() => this.chooseDay());
  }

  private chooseDay(): void {
    const options: string[] = [];
    for (let day = 1; day <= 31; day++) {
      options.push(day + ' 号');
    }
    const uiContext = this.getUIContext();
    uiContext.showTextPickerDialog({
      range: options,
      selected: this.startDay - 1,
      onAccept: (result: TextPickerResult) => {
        if (typeof result.index !== 'number') {
          return;
        }
        const selectedDay = result.index + 1;
        uiContext.runScopedTask(() => this.onChange(selectedDay));
      }
    });
  }
}
