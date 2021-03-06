unit FormOPCDataAccess;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ExtCtrls, ComObj, ActiveX,
  untOPCPublic,
  OPCcustomClasses,
  OPCTypes,
  OPCUtils,
  OPCDA, ComCtrls, ToolWin;

type
  TfrmOPCDataAccess = class(TForm)
    Panel1: TPanel;
    StatusBar1: TStatusBar;
    GroupBox2: TGroupBox;
    mmRunMsg: TMemo;
    GroupBox3: TGroupBox;
    GroupBox4: TGroupBox;
    ToolBar1: TToolBar;
    ListView1: TListView;
    ToolBar2: TToolBar;
    ToolButton1: TToolButton;
    ToolButton2: TToolButton;
    lvGroups: TListView;
    Panel2: TPanel;
    GroupBox1: TGroupBox;
    ledtServersHost: TLabeledEdit;
    ledtOPCServerGUID: TLabeledEdit;
    btnConnectToServer: TButton;
    procedure btnConnectToServerClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  published
    property MainMessageMemo: TMemo read mmRunMsg;
  end;

var
  frmOPCDataAccess: TfrmOPCDataAccess;

implementation

uses
  untMessage;

{$R *.dfm}

const
  RPC_C_AUTHN_LEVEL_NONE = 1;
  RPC_C_IMP_LEVEL_IMPERSONATE = 3;
  EOAC_NONE = 0;

procedure TfrmOPCDataAccess.btnConnectToServerClick(Sender: TObject);
const
  OneSecond = 1 / (24 * 60 * 60);
  gddstServerGUID = '{F8582CF2-88FB-11D0-B850-00C0F0104305}';
  //Item0Name = 'Triangle Waves.Real8';
  //Item1Name = 'Bucket Brigade.Real4';
  //Item0name = 'Random.Real4';
  //Item1Name = 'Random.Real8';

  sOPCServerGUID = '{21C3E5E0-B7E4-11D4-8BE0-0050BACFBB99}';
  //Item0Name = '伊利牛奶厂压力.Value';
  Item0Name = '储罐压力1#.Value';
  Item1Name = 'x02.标况瞬时流量.Value';
var
  ServerIf: IOPCServer;
  groupEnumIf: IInterface;
  enum: IEnumUnknown;
  //groupIf: IInterface;
  pFetched: PLongint;

  GroupIf: IOPCItemMgt;
  GroupHandle: OPCHANDLE;
  Item0Handle: OPCHANDLE;
  Item1Handle: OPCHANDLE;
  ItemType: TVarType;
  ItemValue: string;
  ItemQuality: Word;
  HR: HResult;
  AdviseSink: IAdviseSink;
  AsyncConnection: Longint;
  OPCDataCallback: IOPCDataCallback;
  StartTime: TDateTime;

  pUpdateRate:                DWORD;
  pActive:                    BOOL;
  ppName:                     POleStr;
  pTimeBias:                  Longint;
  pPercentDeadband:           Single;
  pLCID:                      TLCID;
  phClientGroup:              OPCHANDLE;
  phServerGroup:              OPCHANDLE;
begin
  //DCOM权限验证
  HR := CoInitializeSecurity(
    nil,                    // points to security descriptor
    -1,                     // count of entries in asAuthSvc
    nil,                    // array of names to register
    nil,                    // reserved for future use
    RPC_C_AUTHN_LEVEL_NONE, // the default authentication level for proxies
    RPC_C_IMP_LEVEL_IMPERSONATE,// the default impersonation level for proxies
    nil,                    // used only on Windows 2000
    EOAC_NONE,              // additional client or server-side capabilities
    nil                     // reserved for future use
    );
  if Failed(HR) then
  begin
    AddMessageToMemo('验证DCOM安全失败！');
  end;
  //

  try
    ServerIf := CreateRemoteComObject(Trim(ledtServersHost.Text), StringToGUID(ledtOPCServerGUID.Text)) as IOPCServer;
  except
    on e: Exception do
    begin
      ServerIf := nil;
      MyMessage(PChar('连接服务器失败：' + e.Message), DSWARNING);
      Exit;
    end;
  end;

  if ServerIf = nil then
  begin
    AddMessageToMemo('Failed to connect to server.');
  end else
  begin
    AddMessageToMemo('Succeed To Connect To Server.');

    //Add Groups and Items
    // now add a group
    HR := ServerAddGroup(ServerIf, 'MyGroup', True, 500, 0, GroupIf, GroupHandle);
    if Succeeded(HR) then
    begin
      //Writeln('Added group to server');
      AddMessageToMemo('Added group to server');
    end
    else begin
      //Writeln('Unable to add group to server');
      AddMessageToMemo('Unable to add group to server');
      Exit;
    end;

    // now add an item to the group
    HR := GroupAddItem(GroupIf, Item0Name, 0, VT_EMPTY, Item0Handle,
      ItemType);
    if Succeeded(HR) then
    begin
      //Writeln('Added item 0 to group');
      AddMessageToMemo('Added item 0 to group');
    end
    else begin
      //Writeln('Unable to add item 0 to group');
      AddMessageToMemo('Unable to add item 0 to group');
      ServerIf.RemoveGroup(GroupHandle, False);
      Exit;
    end;
    // now add a second item to the group
    HR := GroupAddItem(GroupIf, Item1Name, 1, VT_EMPTY, Item1Handle,
      ItemType);
    if Succeeded(HR) then
    begin
      //Writeln('Added item 1 to group');
      AddMessageToMemo('Added item 1 to group');
    end
    else begin
      //Writeln('Unable to add item 1 to group');
      AddMessageToMemo('Unable to add item 1 to group');
      ServerIf.RemoveGroup(GroupHandle, False);
      Exit;
    end;

    // set up an IDataObject advise callback for the group
    AdviseSink := TOPCAdviseSink.Create;
    HR := GroupAdviseTime(GroupIf, AdviseSink, AsyncConnection);
    if Failed(HR) then
    begin
      AddMessageToMemo('Failed to set up IDataObject advise callback');
    end
    else begin
      AddMessageToMemo('IDataObject advise callback established');
      // continue waiting for callbacks for 10 seconds
      StartTime := Now;
      while (Now - StartTime) < (10 * OneSecond) do
      begin
        Application.ProcessMessages;
      end;
      // end the IDataObject advise callback
      GroupUnadvise(GroupIf, AsyncConnection);
    end;

    // now set up an IConnectionPointContainer data callback for the group
    OPCDataCallback := TOPCDataCallback.Create;
    HR := GroupAdvise2(GroupIf, OPCDataCallback, AsyncConnection);
    if Failed(HR) then
    begin
      AddMessageToMemo('Failed to set up IConnectionPointContainer advise callback');
    end
    else begin
      AddMessageToMemo('IConnectionPointContainer data callback established');
      // continue waiting for callbacks for 10 seconds
      StartTime := Now;
      while (Now - StartTime) < (10 * OneSecond) do
      begin
        Application.ProcessMessages;
      end;
      // end the IConnectionPointContainer data callback
      GroupUnadvise2(GroupIf, AsyncConnection);
    end;

    HR := ReadOPCGroupItemValue(groupIf, Item0Handle, ItemValue, ItemQuality);
    if Succeeded(HR) then
    begin
      if (ItemQuality and OPC_QUALITY_MASK) = OPC_QUALITY_GOOD then
      begin
        AddMessageToMemo('Item 0 value read synchronously as ' + ItemValue);
      end
      else begin
        AddMessageToMemo('Item 0 value was read synchronously, but quality was not good, value is ' + ItemValue);
      end;
    end
    else begin
      AddMessageToMemo('Failed to read item 0 value synchronously');
    end;

    HR := ReadOPCGroupItemValue(groupIf, Item1Handle, ItemValue, ItemQuality);
    if Succeeded(HR) then
    begin
      if (ItemQuality and OPC_QUALITY_MASK) = OPC_QUALITY_GOOD then
      begin
        AddMessageToMemo('Item 1 value read synchronously as ' + ItemValue);
      end
      else begin
        AddMessageToMemo('Item 1 value was read synchronously, but quality was not good, value is ' + ItemValue);
      end;
    end
    else begin
      AddMessageToMemo('Failed to read item 1 value synchronously');
    end;

    (*
    //
    ServerIf.CreateGroupEnumerator(OPC_ENUM_ALL, StringToGUID('{00000100-0000-0000-C000-000000000046}'), groupEnumIf);
    if groupEnumIf <> nil then
    begin
      //ShowMessage('Group Enumerator is not nil');
      if groupEnumIf.QueryInterface(StringToGUID('{00000100-0000-0000-C000-000000000046}'), enum) = S_OK then
      begin
        enum.Reset;
        New(pFetched);
        enum.Next(1, groupIf, pFetched);
        while groupIf <> nil do
        begin
          (groupIf as IOPCGroupStateMgt).GetState(pUpdateRate, pActive, ppName, pTimeBias, pPercentDeadband, pLCID, phClientGroup, phServerGroup);
          //

          //
          New(pFetched);
          enum.Next(1, groupIf, pFetched);
        end;
        ShowMessage('Group enum end.');
      end else
      begin
        ShowMessage('Group enum is invalid.');
      end;
    end else
    begin
      ShowMessage('Group Enumerator is nil');
    end;
    *)

    // now cleanup
    HR := ServerIf.RemoveGroup(GroupHandle, False);
    if Succeeded(HR) then
    begin
      AddMessageToMemo('Removed group');
    end
    else begin
      AddMessageToMemo('Unable to remove group');
    end;
  end;
end;

end.
