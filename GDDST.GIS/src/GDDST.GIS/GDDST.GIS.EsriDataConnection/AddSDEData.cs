﻿using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;
using System.ComponentModel.Composition;

using ESRI.ArcGIS.Geodatabase;
using ESRI.ArcGIS.DataSourcesGDB;
using ESRI.ArcGIS.Controls;
using ESRI.ArcGIS.Carto;
using ESRI.ArcGIS.esriSystem;

using GDDST.GIS.PluginEngine;

namespace GDDST.GIS.EsriDataConnection
{
    [Export(typeof(IDsCommand))]
    public class AddSDEData : DsBaseCommand
    {
        public override void OnCreate(IDsApplication hook)
        {
            base.m_app = hook;
            base.Caption = "加载SDE数据";
            base.Category = "加载数据";
            base.Message = "";
            base.Tooltip = "加载SDE数据";
            base.Name = "AddSDEData";
            base.Checked = false;
            base.Enabled = true;
            base.m_bitmapNameSmall = "AddSDEData_16.png";
            base.m_bitmapNameLarge = "AddSDEData_32.png";

            base.LoadSmallBitmap();
            base.LoadLargeBitmap();
        }

        public override void OnActivate()
        {
            base.OnActivate();

            IMapControlDefault mapCtrl = null;

            if (m_app.MapControl is AxMapControl)
            {
                mapCtrl = ((m_app.MapControl as AxMapControl).Object as IMapControlDefault);
            }
            else
            {
                return;
            }

            WinConnectToSDE winConnToSDE = new WinConnectToSDE();
            winConnToSDE.Owner = m_app.MainWindow;
            if ((bool)winConnToSDE.ShowDialog())
            {
                string server = winConnToSDE.Server;
                string instance = winConnToSDE.Instance;
                string database = winConnToSDE.Database;
                string user = winConnToSDE.User;
                string password = winConnToSDE.Password;
                string version = winConnToSDE.Version;

                IWorkspace ws = OpenSDEWorkspace(server, instance, database, user, password, version);
                if (ws != null)
                {
                    FormSelectDatasets frmSelectDS = new FormSelectDatasets(ws);
                    if (frmSelectDS.ShowDialog() == DialogResult.OK)
                    {
                        List<ILayer> layers = frmSelectDS.SelectedLayers;
                        foreach (ILayer layer in layers)
                        {
                            AddLayerToMap(mapCtrl.Map, layer);
                        }

                        mapCtrl.ActiveView.Extent = frmSelectDS.SelectedExtent;
                        mapCtrl.ActiveView.Refresh();
                    }
                }
            }
        }

        private IWorkspace OpenSDEWorkspace(string server, string instance, string database,
            string user, string password, string version)
        {
            try
            {
                IPropertySet propSet = new PropertySetClass();
                if (server.Trim() != string.Empty)
                {
                    propSet.SetProperty("SERVER", server);
                }
                propSet.SetProperty("INSTANCE", instance);
                propSet.SetProperty("DATABASE", database);
                propSet.SetProperty("USER", user);
                propSet.SetProperty("PASSWORD", password);
                propSet.SetProperty("VERSION", version);

                IWorkspaceFactory wsf = new SdeWorkspaceFactoryClass();
                return wsf.Open(propSet, 0);
            }
            catch (Exception e)
            {
                MessageBox.Show(e.Message);
                return null;
            }
        }

        private void AddLayerToMap(IMap map, ILayer layer)
        {
            (map as IMapLayers2).InsertLayer(layer, true, 0);
        }
    }
}
