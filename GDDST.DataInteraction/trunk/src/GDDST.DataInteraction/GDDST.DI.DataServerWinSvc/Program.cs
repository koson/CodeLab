﻿using System;
using System.Collections.Generic;
using System.Linq;
using System.ServiceProcess;
using System.Text;
using System.Threading.Tasks;

namespace GDDST.DI.DataServerWinSvc
{
    static class Program
    {
        /// <summary>
        /// 应用程序的主入口点。
        /// </summary>
        static void Main()
        {
            ServiceBase[] ServicesToRun;
            ServicesToRun = new ServiceBase[]
            {
                new DataService()
            };
            ServiceBase.Run(ServicesToRun);

            //For Debug
            //DataService ds = new DataService();
            //ds.OnDebug();
            //Console.ReadLine();
        }
    }
}
